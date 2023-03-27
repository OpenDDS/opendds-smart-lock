#include "smartlock_idl_plugin.h"
#include <string>

#include <SmartLockTypeSupportImpl.h>

#include <dds/DCPS/Service_Participant.h>
#include <dds/DCPS/Marked_Default_Qos.h>
#include <dds/DCPS/BuiltInTopicUtils.h>
#include <dds/DCPS/SequenceIterator.h>

#include <ace/OS_NS_stdio.h>
#include <ace/OS_NS_sys_socket.h>
#include <ace/OS_NS_arpa_inet.h>

class DataReaderListenerImpl: public DDS::DataReaderListener
{
public:
  DataReaderListenerImpl() {}
  ~DataReaderListenerImpl() {}

  void on_requested_deadline_missed (
      ::DDS::DataReader_ptr reader,
      const ::DDS::RequestedDeadlineMissedStatus & status) override {}

  void on_requested_incompatible_qos (
      ::DDS::DataReader_ptr reader,
      const ::DDS::RequestedIncompatibleQosStatus & status) override {}

  void on_sample_rejected (
      ::DDS::DataReader_ptr reader,
      const ::DDS::SampleRejectedStatus & status) override {}

  void on_liveliness_changed (
      ::DDS::DataReader_ptr reader,
      const ::DDS::LivelinessChangedStatus & status) override {}

  void on_data_available (
      ::DDS::DataReader_ptr reader) override {
    SmartLock::StatusDataReader_var mdr = SmartLock::StatusDataReader::_narrow(reader);
    if (mdr == nullptr) {
      ACE_DEBUG((LM_NOTICE, "%s: read: narrow failed.\n", LOGTAG));
      return;
    }

    SmartLock::Status mh;
    DDS::SampleInfo sih;
    const int status = mdr->take_next_sample(mh, sih);
    if (status == DDS::RETCODE_OK) {
      SmartLockStatus lock_status;
#if defined(OPENDDS_HAS_CXX11)
      lock_status.id = mh.lock().id().c_str();
#else
      lock_status.id = mh.lock.id;
#endif
      if (sih.valid_data) {
        lock_status.enabled = true;
#if defined(OPENDDS_HAS_CXX11)
        lock_status.state = mh.lock().locked() ? LOCKED : UNLOCKED;
#else
        lock_status.state = mh.lock.locked ? LOCKED : UNLOCKED;
#endif
      } else {
        lock_status.enabled = false;
      }
      update(&lock_status);
    }
  }

  void on_subscription_matched (
      ::DDS::DataReader_ptr reader,
      const ::DDS::SubscriptionMatchedStatus & status) override {}

  void on_sample_lost (
      ::DDS::DataReader_ptr reader,
      const ::DDS::SampleLostStatus & status) override {}

  static void setPort(short port) {
    send_port = port;
  }

private:
  static void update(const SmartLockStatus* status) {
    // NOTE: Using Dart_PostCObject_DL() was causing a segmentation fault.
    // As a fallback, I chose to send data back to the Dart main thread using
    // a loopback socket.
    //
    //Dart_CObject msg;
    //msg.type = Dart_CObject_kNativePointer;
    //SmartLockStatus* copy = reinterpret_cast<SmartLockStatus*>(malloc(sizeof(*status)));
    //memcpy(copy, status, sizeof(*copy));
    //copy->id = strdup(status->id);
    //msg.value.as_native_pointer.ptr = reinterpret_cast<intptr_t>(copy);
    //msg.value.as_native_pointer.size = sizeof(*copy);
    //msg.value.as_native_pointer.callback = dart_finalizer;
    //Dart_PostCObject_DL(send_port, &msg);

    static ACE_HANDLE sd = ACE_INVALID_HANDLE;
    if (sd == ACE_INVALID_HANDLE) {
      sd = ACE_OS::socket(AF_INET, SOCK_STREAM, 0);
      if (sd != ACE_INVALID_HANDLE) {
        struct sockaddr_in serv_addr;
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(send_port);
        ACE_OS::inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr);
        ACE_OS::connect(sd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));
      }
    }

    if (sd != ACE_INVALID_HANDLE) {
      const size_t bytes = 2;
      const size_t len = strlen(status->id);
      const size_t total = bytes + len;
      uint8_t* buffer = new uint8_t[total];
      if (buffer != nullptr) {
        buffer[0] = static_cast<uint8_t>(status->state);
        buffer[1] = static_cast<uint8_t>(status->enabled);
        ACE_OS::memcpy(buffer + bytes, status->id, len);
        ACE_OS::send(sd, reinterpret_cast<const char*>(buffer), total, 0);
        delete [] buffer;
      }
    }
  }

  static short send_port;
  static const char* LOGTAG;
};

short DataReaderListenerImpl::send_port = 0;
const char* DataReaderListenerImpl::LOGTAG = "SmartLock_DataReaderListenerImpl";

class OpenDdsBridgeImpl
{
public:
  OpenDdsBridgeImpl()
   : secure(true),
     debug_level("3"),
     transport_debug_level("3"),
     topic_prefix("C.53."),
     domain(1),
     groups() {
  }

  void run(const OpenDdsBridgeConfig* config) {
    startDds(config);
    try {
      initParticipant();
      if (send != nullptr) {
        send("The OpenDDS Bridge is running");
      }
    }
    catch(const std::exception& e) {
      error_message = e.what();
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
    }
  }

  static void shutdown() {
    ACE_DEBUG((LM_NOTICE, "%s: Shutting down\n", LOG_TAG));
    if (participant != nullptr) {
      participant->delete_contained_entities();
      if (participantFactory != nullptr) {
        participantFactory->delete_participant(participant);
      }
      participant = nullptr;
    }
    dw = nullptr;
    TheServiceParticipant->shutdown();
  }

  void updateLockState(const SmartLockStatus* status) {
    if (dw != nullptr) {
      ACE_DEBUG((LM_NOTICE, "%s: Writing Control Update %s:%d\n",
                            LOG_TAG, status->id, status->state));
      SmartLock::ControlDataWriter_var control_dw =
        SmartLock::ControlDataWriter::_narrow(dw);

#if defined(OPENDDS_HAS_CXX11)
      SmartLock::Control control_message(
        SmartLock::lock_t(status->id,
                          status->state == PENDING_LOCK ||
                          status->state == LOCKED,
                          SmartLock::vec2(20, 10)));
#else
      SmartLock::Control control_message;
      control_message.lock.id = status->id;
      control_message.lock.locked = status->state == PENDING_LOCK ||
                                    status->state == LOCKED;
      control_message.lock.position.x = 20;
      control_message.lock.position.y = 10;
#endif
      const int return_code = control_dw->write(control_message,
                                                control_dw->register_instance(control_message));
      if (return_code != DDS::RETCODE_OK) {
        ACE_DEBUG((LM_NOTICE, "%s: Error writing control update, return code was %d\n",
                              LOG_TAG, return_code));
      }
    }
  }

  static notifier send;

private:
  void initParticipantFactory(const OpenDdsBridgeConfig* config) {
    if (participantFactory != nullptr) {
      return;
    }

    std::vector<const char*> args;
    args.push_back("program");
    args.push_back("-DCPSTransportDebugLevel");
    args.push_back(transport_debug_level.c_str());
    args.push_back("-DCPSDebugLevel");
    args.push_back(debug_level.c_str());
    args.push_back("-DCPSConfigFile");
    args.push_back(config->ini);

    if (secure) {
      args.push_back("-DCPSSecurity");
      args.push_back("1");
    }

    int argc = args.size();
    participantFactory =
      TheParticipantFactoryWithArgs(argc, const_cast<char**>(args.data()));
    if (participantFactory != nullptr) {
      participantFactory->get_default_participant_qos(participantQos);

      OpenDDS::DCPS::SequenceBackInsertIterator<DDS::PropertySeq>
        props(participantQos.property.value);
      if (secure && TheServiceParticipant->get_security()) {
        std::string file("file:");
        *props = {"dds.sec.auth.identity_ca", (file + config->id_ca).c_str(), false};
        *props = {"dds.sec.auth.identity_certificate", (file + config->id_cert).c_str(), false};
        *props = {"dds.sec.auth.private_key", (file + config->id_pkey).c_str(), false};
        *props = {"dds.sec.access.permissions_ca", (file + config->perm_ca).c_str(), false};
        *props = {"dds.sec.access.governance", (file + config->perm_gov).c_str(), false};
        *props = {"dds.sec.access.permissions", (file + config->perm_perms).c_str(), false};
      }
    }
    else {
      error_message = "participant factory initialization failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }
  }

  void startDds(const OpenDdsBridgeConfig* config) {
    error_message.clear();
    if (participant == nullptr) {
      try {
        initParticipantFactory(config);
      } catch (const std::exception& e) {
        error_message = "Error Initializing OpenDDS: ";
        error_message += e.what();
        ACE_DEBUG((LM_NOTICE, "%s: %s\n", LOG_TAG, error_message.c_str()));
        if (send != nullptr) {
          send(error_message.c_str());
        }
      }
    }
  }

  void initParticipant() {
    error_message.clear();
    if (participant != nullptr) {
      return;
    }

    participant =
      participantFactory->create_participant(domain,
                                             participantQos,
                                             nullptr,
                                             OpenDDS::DCPS::DEFAULT_STATUS_MASK);
    if (participant == nullptr) {
      error_message = "create_participant failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    SmartLock::StatusTypeSupport_var status_ts =
      new SmartLock::StatusTypeSupportImpl;
    if (status_ts->register_type(participant, "") != DDS::RETCODE_OK) {
      error_message = "register_type failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    const std::string status_topic_name = topic_prefix + "SmartLock Status";
    CORBA::String_var type_name = status_ts->get_type_name();
    DDS::Topic_var status_topic =
      participant->create_topic(status_topic_name.c_str(),
                                type_name,
                                TOPIC_QOS_DEFAULT,
                                nullptr,
                                OpenDDS::DCPS::DEFAULT_STATUS_MASK);
    if (status_topic == nullptr) {
      error_message = "create_topic ";
      error_message += status_topic_name;
      error_message += " failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    DDS::SubscriberQos sub_qos;
    participant->get_default_subscriber_qos(sub_qos);

    DDS::Subscriber_var sub = participant->create_subscriber(sub_qos, nullptr,
      OpenDDS::DCPS::DEFAULT_STATUS_MASK);
    if (sub == nullptr) {
      error_message = "create_subscriber failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    // Create DataReader
    DDS::DataReaderQos read_qos;
    sub->get_default_datareader_qos(read_qos);
    read_qos.reliability.kind = DDS::RELIABLE_RELIABILITY_QOS;
    read_qos.history.kind = DDS::KEEP_ALL_HISTORY_QOS;
    DDS::DataReaderListener_var listener = new DataReaderListenerImpl;
    DDS::DataReader_var reader =
      sub->create_datareader(status_topic,
                             read_qos,
                             listener,
                             OpenDDS::DCPS::DEFAULT_STATUS_MASK);
    if (reader == nullptr) {
      error_message = "create_datareader failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    DDS::Subscriber_var builtinSubscriber = participant->get_builtin_subscriber();
    if (builtinSubscriber == nullptr) {
      error_message = "get_builtin_subscriber failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    DDS::DataReader_var bitDr =
      builtinSubscriber->lookup_datareader(
        OpenDDS::DCPS::BUILT_IN_PARTICIPANT_LOCATION_TOPIC);
    if (bitDr == nullptr) {
      error_message = "lookup_datareader failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    // TODO: locationListener?
    //locationListener = new ParticipantLocationListener();
    //int ret = bitDr.set_listener(locationListener, OpenDDS.DCPS.DEFAULT_STATUS_MASK.value);
    //assert (ret == DDS.RETCODE_OK.value);

    SmartLock::ControlTypeSupport_var control_servant =
      new SmartLock::ControlTypeSupportImpl();
    if (control_servant->register_type(participant, "") != DDS::RETCODE_OK) {
      error_message = "Control register_type failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    const std::string control_topic_name = topic_prefix + "SmartLock Control";
    type_name = control_servant->get_type_name();
    DDS::Topic_var control_topic =
      participant->create_topic(control_topic_name.c_str(),
                                type_name,
                                TOPIC_QOS_DEFAULT,
                                nullptr,
                                OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (control_topic == nullptr) {
      error_message = "create_topic ";
      error_message += control_topic_name;
      error_message += " failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    DDS::PublisherQos pub_qos;
    participant->get_default_publisher_qos(pub_qos);
    DDS::Publisher_var publisher =
      participant->create_publisher(pub_qos,
                                    nullptr,
                                    OpenDDS::DCPS::DEFAULT_STATUS_MASK);
    if (publisher == nullptr) {
      error_message = "create_publisher failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }

    DDS::DataWriterQos writer_qos;
      publisher->get_default_datawriter_qos(writer_qos);
    dw = publisher->create_datawriter(control_topic,
                                      writer_qos,
                                      nullptr,
                                      OpenDDS::DCPS::DEFAULT_STATUS_MASK);
    if (dw == nullptr) {
      error_message = "create_datawriter failed!";
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: ")
                 ACE_TEXT("%s\n"),
                 error_message.c_str()));
      if (send != nullptr) {
        send(error_message.c_str());
      }
      return;
    }
  }

  std::string error_message;

  static const char* LOG_TAG;

  static DDS::DomainParticipantFactory_var participantFactory;
  static DDS::DomainParticipant_var participant;
  //static DDS::DataReaderListener_var locationListener;
  static DDS::DataWriter_var dw;

  DDS::DomainParticipantQos participantQos;

  bool secure;
  std::string debug_level;
  std::string transport_debug_level;
  std::string topic_prefix;
  int domain;
  std::vector<std::string> groups;
};

notifier OpenDdsBridgeImpl::send;

const char* OpenDdsBridgeImpl::LOG_TAG = "SmartLock_OpenDDS_Bridge";
DDS::DomainParticipantFactory_var OpenDdsBridgeImpl::participantFactory;
DDS::DomainParticipant_var OpenDdsBridgeImpl::participant;
//DDS::DataReaderListener_var OpenDdsBridgeImpl::locationListener;
DDS::DataWriter_var OpenDdsBridgeImpl::dw;

extern "C" {

OpenDdsBridge* createOpenDdsBridge()
{
  OpenDdsBridge* bridge = new OpenDdsBridge();
  if (bridge != nullptr) {
    bridge->ptr = new OpenDdsBridgeImpl();
    if (bridge->ptr == nullptr) {
      delete bridge;
      bridge = nullptr;
    }
  }
  return bridge;
}

void destroyOpenDdsBridge(OpenDdsBridge* bridge)
{
  if (bridge != nullptr) {
    delete reinterpret_cast<OpenDdsBridgeImpl*>(bridge->ptr);
    delete bridge;
  }
}

void startOpenDdsBridge(OpenDdsBridge* bridge,
                        const OpenDdsBridgeConfig* config)
{
  OpenDdsBridgeImpl::send = config->receiver;
  DataReaderListenerImpl::setPort(config->send_port);
  if (bridge != nullptr) {
    reinterpret_cast<OpenDdsBridgeImpl*>(bridge->ptr)->run(config);
  }
}

void updateOpenDdsBridgeLockState(OpenDdsBridge* bridge,
                                   const SmartLockStatus* status)
{
  if (bridge != nullptr) {
    reinterpret_cast<OpenDdsBridgeImpl*>(bridge->ptr)->updateLockState(status);
  }
}

void shutdownOpenDdsBridge() {
  OpenDdsBridgeImpl::shutdown();
}

}
