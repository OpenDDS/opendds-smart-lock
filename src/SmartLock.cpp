#include <iostream>
#include <thread>
#include <csignal>

#include <ace/Arg_Shifter.h>
#include <ace/Global_Macros.h>
#include <ace/Log_Msg.h>
#include <ace/OS_NS_stdlib.h>

#include <dds/DdsDcpsInfrastructureC.h>
#include <dds/DdsDcpsPublicationC.h>
#include <dds/DdsDcpsSubscriptionC.h>
#include <dds/DdsDcpsCoreTypeSupportImpl.h>

#include <dds/DCPS/Definitions.h>
#include <dds/DCPS/LocalObject.h>
#include <dds/DCPS/Marked_Default_Qos.h>
#include <dds/DCPS/Service_Participant.h>
#include <dds/DCPS/StaticIncludes.h>
#include <dds/DCPS/WaitSet.h>
#include <dds/DCPS/SequenceIterator.h>

#include "Idl/SmartLockTypeSupportC.h"
#include "Idl/SmartLockTypeSupportImpl.h"

std::ostream& operator<< (std::ostream& lhs, const SmartLock::lock_t& rhs) {
  lhs << "lock: id: '" << rhs.id() << "', locked: '" << rhs.locked()
      << "', position: x: '" << rhs.position().x()
                << "', y: '" << rhs.position().y() << "'";
  return lhs;
}

#if defined(HAS_PIGPIO)

#include <pigpio.h>

const unsigned UNLOCKED_LIGHT = 11;
const unsigned LOCKED_LIGHT = 10;

void pi_unlock() {
  gpioWrite(LOCKED_LIGHT, PI_LOW);
  gpioWrite(UNLOCKED_LIGHT, PI_HIGH);
}

void pi_lock() {
  gpioWrite(UNLOCKED_LIGHT, PI_LOW);
  gpioWrite(LOCKED_LIGHT, PI_HIGH);
}

void pi_clear() {
  gpioWrite(UNLOCKED_LIGHT, PI_LOW);
  gpioWrite(LOCKED_LIGHT, PI_LOW);
}

void pi_init() {
  if (gpioInitialise() < 0) {
    ACE_ERROR((LM_ERROR, "ERROR: pigpio initialisation failed\n"));
    return;
  }

  gpioSetMode(LOCKED_LIGHT, PI_OUTPUT);
  gpioSetMode(UNLOCKED_LIGHT, PI_OUTPUT);
}

void pi_lock_when_locked(const SmartLock::lock_t& lock) {
  if (lock.locked()) {
    pi_lock();

  } else {
    pi_unlock();
  }
}
#endif

namespace DCPS = OpenDDS::DCPS;

enum Role {
  kUnknown,
  kSmartLock,
  kUser,
  kDealer

} role = kUnknown;

void groups_to_partitions(const std::vector<std::string>& src, DDS::PartitionQosPolicy& dest) {
  dest.name.length(src.size());
  for(auto i = 0u; i < dest.name.length(); ++i) {
    dest.name[i] = src[i].c_str();
  }
}

class PartitionedPublisher {
protected:

  PartitionedPublisher(DDS::DomainParticipant_var dp,
                       const std::vector<std::string>& groups) : participant_(dp)
  {
    DDS::PublisherQos qos;
    dp->get_default_publisher_qos(qos);

    groups_to_partitions(groups, partition_);
    qos.partition = partition_;

    publisher_ = dp->create_publisher(qos, 0, OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (! publisher_) {
      ACE_ERROR((LM_ERROR,
          "ERROR: %N:%l: PartitionedPublisher::PartitionedPublisher(): "
          "create_publisher failed!\n"));
    }
  }

  virtual ~PartitionedPublisher() = default;

  DDS::DomainParticipant_var participant_;
  DDS::Publisher_var publisher_;
  DDS::PartitionQosPolicy partition_;
};

class PartitionedSubscriber {
protected:

  PartitionedSubscriber(DDS::DomainParticipant_var dp,
                       const std::vector<std::string>& groups) : participant_(dp)
  {
    DDS::SubscriberQos qos;
    dp->get_default_subscriber_qos(qos);

    groups_to_partitions(groups, partition_);
    qos.partition = partition_;

    subscriber_ = dp->create_subscriber(qos, 0, OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (! subscriber_) {
      ACE_ERROR((LM_ERROR,
          "ERROR: %N:%l: PartitionedPublisher::PartitionedPublisher(): "
          "create_subscriber failed!\n"));
    }
  }

  virtual ~PartitionedSubscriber() = default;

  DDS::DomainParticipant_var participant_;
  DDS::Subscriber_var subscriber_;
  DDS::PartitionQosPolicy partition_;
};

struct ControlReader : private PartitionedSubscriber {
  DDS::Topic_ptr control_topic;
  SmartLock::Status& message;

  ControlReader (const std::vector<std::string>& groups,
                 DDS::DomainParticipant_var a_participant,
                 DDS::Topic_ptr a_topic,
                 SmartLock::Status& a_message)
    : PartitionedSubscriber(a_participant, groups),
      control_topic(a_topic),
      message(a_message)
  {
  }

  void operator() () {
    if (!subscriber_) return;

    DDS::DataReaderQos qos;
    subscriber_->get_default_datareader_qos(qos);

    // Create DataReader
    DDS::DataReader_var reader =
      subscriber_->create_datareader(control_topic,
                                     qos,
                                     NULL,
                                     OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (!reader) {
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: main() -")
                 ACE_TEXT(" create_datareader failed!\n")));
      return;
    }

    SmartLock::ControlDataReader_var reader_i =
      SmartLock::ControlDataReader::_narrow(reader);

    if (!reader_i) {
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: main() -")
                 ACE_TEXT(" _narrow failed!\n")));
      return;
    }

    DDS::StatusCondition_var cond = reader->get_statuscondition();
    cond->set_enabled_statuses(DDS::DATA_AVAILABLE_STATUS);
    DDS::WaitSet_var ws = new DDS::WaitSet;
    ws->attach_condition(cond);

    DDS::ConditionSeq active;
    DDS::Duration_t forever = {DDS::DURATION_INFINITE_SEC, DDS::DURATION_INFINITE_NSEC};

    for (;;) {
      int result = ws->wait(active, forever);
      if (result == DDS::RETCODE_OK) {
        SmartLock::Control control_message;
        DDS::SampleInfo info;
        DDS::ReturnCode_t error = reader_i->take_next_sample(control_message, info);
        if (error == DDS::RETCODE_OK) {

          if (info.valid_data) {
            if (control_message.lock().id() != message.lock().id())
              continue;

            std::cout << " Reading Control: " << control_message.lock() << "\n";

            message.lock(control_message.lock());

#if defined(HAS_PIGPIO)
            pi_lock_when_locked(message.lock());
#endif

          }
        } else {
          ACE_ERROR((LM_ERROR,
                     ACE_TEXT("ERROR: %N:%l: on_data_available() -")
                     ACE_TEXT(" take_next_sample failed!\n")));
        }
      }
    }
  }
};

struct StatusWriter : private PartitionedPublisher {

  const std::string smartlock_id;
  DDS::Topic_ptr status_topic;
  SmartLock::Status& message;

  StatusWriter(const std::vector<std::string>& groups,
               DDS::DomainParticipant_var a_participant,
               DDS::Topic_ptr a_status_topic,
               SmartLock::Status& a_message)
    : PartitionedPublisher(a_participant, groups),
      smartlock_id(a_message.lock().id()),
      status_topic(a_status_topic),
      message(a_message)
  {
  }

  void operator() () {
    if (!publisher_) return;

    DDS::DataWriterQos qos;
    publisher_->get_default_datawriter_qos(qos);

    // Create DataWriter
    DDS::DataWriter_var writer =
      publisher_->create_datawriter(status_topic,
                                    qos,
                                    0,
                                    OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (!writer) {
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: main() -")
                 ACE_TEXT(" create_datawriter failed!\n")));
      return;
    }

    SmartLock::StatusDataWriter_var message_writer =
      SmartLock::StatusDataWriter::_narrow(writer);

    if (!message_writer) {
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: main() -")
                 ACE_TEXT(" _narrow failed!\n")));
      return;
    }

    // Write samples
    for (;;) {

      DDS::ReturnCode_t error = message_writer->write(message, DDS::HANDLE_NIL);
      if (error != DDS::RETCODE_OK) {
        ACE_ERROR((LM_ERROR,
                   ACE_TEXT("ERROR: %N:%l: main() -")
                   ACE_TEXT(" write returned %d!\n"), error));
      }
      std::cout << " Writing Status:  " << message.lock() << "\n";

      ACE_OS::sleep(5);
    }
  }
};

int run_smartlock(const SmartLock::lock_t& start,
                  const std::vector<std::string>& groups,
                  DDS::DomainParticipant_var participant,
                  DDS::Topic_ptr status_topic,
                  DDS::Topic_ptr control_topic) {
  SmartLock::Status message(start);

#if defined(HAS_PIGPIO)
  pi_lock_when_locked(message.lock());
#endif

  // Spawn a thread to read the control.
  ControlReader cr(groups, participant, control_topic, message);
  std::thread control_reader_thread(cr);

  // Spawn a thread to write the status.
  StatusWriter sw(groups, participant, status_topic, message);
  std::thread status_writer_thread(sw);

  status_writer_thread.join();
  control_reader_thread.join();

  return 0;
}

struct StatusReader : private PartitionedSubscriber {
  DDS::Topic_ptr status_topic;

  StatusReader (const std::vector<std::string>& groups,
                DDS::DomainParticipant_var a_participant,
                DDS::Topic_ptr a_topic)
  : PartitionedSubscriber(a_participant, groups),
    status_topic(a_topic)
  {
  }

  void operator() () {
    if (!subscriber_) return;

    DDS::DataReaderQos qos;
    subscriber_->get_default_datareader_qos(qos);

    // Create DataReader
    DDS::DataReader_var reader =
      subscriber_->create_datareader(status_topic,
                                     qos,
                                     NULL,
                                     OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (!reader) {
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: main() -")
                 ACE_TEXT(" create_datareader failed!\n")));
      return;
    }

    SmartLock::StatusDataReader_var reader_i =
      SmartLock::StatusDataReader::_narrow(reader);

    if (!reader_i) {
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: main() -")
                 ACE_TEXT(" _narrow failed!\n")));
      return;
    }

    DDS::StatusCondition_var cond = reader->get_statuscondition();
    cond->set_enabled_statuses(DDS::DATA_AVAILABLE_STATUS);
    DDS::WaitSet_var ws = new DDS::WaitSet;
    ws->attach_condition(cond);

    DDS::ConditionSeq active;
    DDS::Duration_t forever = {DDS::DURATION_INFINITE_SEC, DDS::DURATION_INFINITE_NSEC};


    for (;;) {
      int result = ws->wait(active, forever);
      if (result == DDS::RETCODE_OK) {
        SmartLock::Status status_message;
        DDS::SampleInfo info;
        DDS::ReturnCode_t error = reader_i->take_next_sample(status_message, info);
        if (error == DDS::RETCODE_OK) {
          // std::cout << "SampleInfo.sample_rank = " << info.sample_rank << std::endl;
          // std::cout << "SampleInfo.instance_state = " << info.instance_state << std::endl;

          if (info.valid_data) {
            std::cout << " Reading Status:  " << status_message.lock() << "\n";
          }
        }  else {
          ACE_ERROR((LM_ERROR,
                     ACE_TEXT("ERROR: %N:%l: on_data_available() -")
                     ACE_TEXT(" take_next_sample failed!\n")));
        }
      }
    }
  }
};

struct ControlWriter : private PartitionedPublisher {

  const std::string smartlock_id;
  DDS::Topic_ptr control_topic;

  ControlWriter(const std::string& a_smartlock_id,
                const std::vector<std::string>& groups,
                DDS::DomainParticipant_var a_participant,
                DDS::Topic_ptr a_control_topic)
    : PartitionedPublisher(a_participant, groups),
      smartlock_id(a_smartlock_id),
      control_topic(a_control_topic)
  {
  }

  void operator() () {
    if (!publisher_) return;

    DDS::DataWriterQos qos;
    publisher_->get_default_datawriter_qos(qos);

    // Create DataWriter
    DDS::DataWriter_var writer =
      publisher_->create_datawriter(control_topic,
                                    qos,
                                    0,
                                    OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (!writer) {
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: main() -")
                 ACE_TEXT(" create_datawriter failed!\n")));
      return;
    }



    SmartLock::ControlDataWriter_var message_writer =
      SmartLock::ControlDataWriter::_narrow(writer);

    if (!message_writer) {
      ACE_ERROR((LM_ERROR,
                 ACE_TEXT("ERROR: %N:%l: main() -")
                 ACE_TEXT(" _narrow failed!\n")));
      return;
    }

    // Write samples
    SmartLock::Control message(SmartLock::lock_t(
                                smartlock_id, true,
                                SmartLock::vec2(20.0f, 10.0f)));

    for (;;) {

      DDS::ReturnCode_t error = message_writer->write(message, DDS::HANDLE_NIL);
      if (error != DDS::RETCODE_OK) {
        ACE_ERROR((LM_ERROR,
                   ACE_TEXT("ERROR: %N:%l: main() -")
                   ACE_TEXT(" write returned %d!\n"), error));
      }
      std::cout << " Writing Control: " << message.lock() << "\n";

      ACE_OS::sleep(5);
    }
  }
};

int run_user(const std::string& smartlock_id,
              const std::vector<std::string>& groups,
              DDS::DomainParticipant_var participant,
              DDS::Topic_ptr status_topic,
              DDS::Topic_ptr control_topic) {

  // Spawn a thread to read the status.
  StatusReader sr(groups, participant, status_topic);
  std::thread status_reader_thread(sr);

  // Spawn a thread to control the set point.
  ControlWriter cw(smartlock_id, groups, participant, control_topic);
  std::thread control_writer_thread(cw);

  control_writer_thread.join();
  status_reader_thread.join();

  return 0;
}

void usage(std::ostream& out) {
  out << "Usage: smartlock -h | -lock SMARTLOCK_ID [-user | -dealer] -groups GROUP_0 [GROUP_1...GROUP_N] [OPTIONS ...]" << std::endl
    << "OPTIONS:" << std::endl
    << "  SmartLock Options:" << std::endl
    << "    -x X_POSITION | -y Y_POSITION" << std::endl
#if defined(OPENDDS_SECURITY)
    << "  Security Options:" << std::endl
    << "    -ID_CA file | -ID_CERT file | -ID_PKEY file | -PERM_CA file | -PERM_GOV file | -PERM_PERMS file" << std::endl
#endif
    ;
}

#if defined(OPENDDS_SECURITY)
struct SecurityInfo {
  std::string id_ca;
  std::string id_cert;
  std::string id_pkey;
  std::string perm_ca;
  std::string perm_gov;
  std::string perm_perms;

  SecurityInfo(int argc, char* argv[]) : arg_supplied(false) {
    ACE_Arg_Shifter args(argc, argv);

    while (args.is_anything_left()) {
      const char* arg = nullptr;

      if ((arg = args.get_the_parameter("-ID_CA")) != nullptr) {
        id_ca = "file:" + std::string(arg);
        arg_supplied = true;
        args.consume_arg();

      } else if ((arg = args.get_the_parameter("-ID_CERT")) != nullptr) {
        id_cert = "file:" + std::string(arg);
        arg_supplied = true;
        args.consume_arg();

      } else if ((arg = args.get_the_parameter("-ID_PKEY")) != nullptr) {
        id_pkey = "file:" + std::string(arg);
        arg_supplied = true;
        args.consume_arg();

      } else if ((arg = args.get_the_parameter("-PERM_CA")) != nullptr) {
        perm_ca = "file:" + std::string(arg);
        arg_supplied = true;
        args.consume_arg();

      } else if ((arg = args.get_the_parameter("-PERM_GOV")) != nullptr) {
        perm_gov = "file:" + std::string(arg);
        arg_supplied = true;
        args.consume_arg();

      } else if ((arg = args.get_the_parameter("-PERM_PERMS")) != nullptr) {
        perm_perms = "file:" + std::string(arg);
        arg_supplied = true;
        args.consume_arg();

      } else {
        args.ignore_arg();
      }
    }
  }
  ~SecurityInfo() = default;

  bool is_valid() {
    return (id_ca != "" && id_cert != "" && id_pkey != "" && perm_ca != "" && perm_gov != "" && perm_perms != "");
  }

  bool was_arg_supplied() { return arg_supplied; }
private:
  bool arg_supplied;
};

std::ostream& operator<<(std::ostream& lhs, const SecurityInfo& rhs) {
  lhs << "ID_CA: '" << rhs.id_ca << "', ID_CERT: '" << rhs.id_cert << "', ID_PKEY: '" << rhs.id_pkey
      << "', PERM_CA: '" << rhs.perm_ca << "', PERM_GOV: '" << rhs.perm_gov << "', PERM_PERMS: '" << rhs.perm_perms << "'";
  return lhs;
}
#endif

DDS::DomainParticipantFactory_var dpf = nullptr;
DDS::DomainParticipant_var participant = nullptr;

void cleanup() {
#if defined(HAS_PIGPIO)
  if (role == kSmartLock) pi_clear();
#endif

  if (dpf) {
    try {
      std::cerr << "Shutting down...\n";

      if (participant) {
        participant->delete_contained_entities();
        dpf->delete_participant(participant);
        participant = nullptr;
      }

      TheServiceParticipant->shutdown();
      dpf = nullptr;

      std::cerr << "Done\n";

    } catch (const CORBA::Exception& e) {
      e._tao_print_exception("Exception caught in main():");
      exit(1);
    }
  }
}

extern "C" void exit_handler(int) {
  std::cerr << "Interrupted...\n";

  cleanup();

  exit(0);
}

int ACE_TMAIN(int argc, ACE_TCHAR *argv[])
{
  std::signal(SIGINT, exit_handler);

  try {
    dpf = TheParticipantFactoryWithArgs(argc, argv);

    std::vector<std::string> groups;
    SmartLock::lock_t lock;

    ACE_Arg_Shifter args(argc, argv);
    while (args.is_anything_left()) {
      const char* arg = nullptr;

      if ((arg = args.get_the_parameter("-lock")) != nullptr) {
        role = kSmartLock;
        lock.id(arg);
        args.consume_arg();

      } else if ((arg = args.get_the_parameter("-x")) != nullptr) {
        try {
          lock.position().x(std::stof(arg));

        } catch (const std::logic_error&) {
          ACE_ERROR((LM_ERROR, "ERROR: Invalid number passed to -x\n"));
          return 1;
        }
        args.consume_arg();

      } else if ((arg = args.get_the_parameter("-y")) != nullptr) {
        try {
          lock.position().y(std::stof(arg));

        } catch (const std::logic_error&) {
          ACE_ERROR((LM_ERROR, "ERROR: Invalid number passed to -y\n"));
          return 1;
        }
        args.consume_arg();

      } else if (std::strcmp(args.get_current(), "-h") == 0) {
        usage(std::cout);
        return 0;

      } else if (std::strcmp(args.get_current(), "-user") == 0) {
        if (role == kDealer) {
          ACE_ERROR((LM_ERROR, "ERROR: -dealer and -user cannot both be specified\n"));
          usage(std::cerr);
          return 1;
        }
        role = kUser;
        args.consume_arg();

      } else if (std::strcmp(args.get_current(), "-dealer") == 0) {
        if (role == kUser) {
          ACE_ERROR((LM_ERROR, "ERROR: -dealer and -user cannot both be specified\n"));
          usage(std::cerr);
          return 1;
        }
        role = kDealer;
        args.consume_arg();

      } else if ((arg = args.get_the_parameter("-groups")) != nullptr) {

        do {
          groups.push_back(std::string(args.get_current()));
          args.consume_arg();

        } while (args.is_parameter_next());

      } else {
        args.ignore_arg();
      }
    }

    if (role == kUnknown || lock.id().empty()) {
      usage(std::cerr);
      return -1;
    }

    DDS::DomainParticipantQos part_qos;
    dpf->get_default_participant_qos(part_qos);

    std::string group_str;
    for (auto group : groups) {
      if (!group_str.empty()) {
        group_str += "," + group;
      } else {
        group_str += group;
      }
    }

    std::cout << "group_str=" << group_str << std::endl;

    OpenDDS::DCPS::SequenceBackInsertIterator<DDS::PropertySeq> props(part_qos.property.value);
    *props = {"OpenDDS.RtpsRelay.Groups", group_str.c_str(), true};

#if defined(OPENDDS_SECURITY)
    if (TheServiceParticipant->get_security()) {
      SecurityInfo security_info(argc, argv);

      if (security_info.was_arg_supplied()) {
        std::cout << "Security Configs: " << security_info << "\n";

        if (! security_info.is_valid()) {
          std::cerr << "ERROR: All security arguments above must be provided\n";
          usage(std::cerr);
          return -1;
        }

        *props = {"dds.sec.auth.identity_ca", security_info.id_ca.c_str(), false};
        *props = {"dds.sec.auth.identity_certificate", security_info.id_cert.c_str(), false};
        *props = {"dds.sec.auth.private_key", security_info.id_pkey.c_str(), false};
        *props = {"dds.sec.access.permissions_ca", security_info.perm_ca.c_str(), false};
        *props = {"dds.sec.access.governance", security_info.perm_gov.c_str(), false};
        *props = {"dds.sec.access.permissions", security_info.perm_perms.c_str(), false};
      }
    }
#endif

    DDS::PartitionQosPolicy partitions;
    groups_to_partitions(groups, partitions);

    // Create DomainParticipant
    participant =
      dpf->create_participant(42,
                              part_qos,
                              0,
                              OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (!participant) {
      ACE_ERROR_RETURN((LM_ERROR,
                        ACE_TEXT("ERROR: %N:%l: main() -")
                        ACE_TEXT(" create_participant failed!\n")),
                       -1);
    }

    // Register TypeSupport
    // SmartLock::Status
    SmartLock::StatusTypeSupport_var status_ts =
      new SmartLock::StatusTypeSupportImpl;

    if (status_ts->register_type(participant, "") != DDS::RETCODE_OK) {
      ACE_ERROR_RETURN((LM_ERROR,
                        ACE_TEXT("ERROR: %N:%l: main() -")
                        ACE_TEXT(" register_type failed!\n")),
                       -1);
    }

    SmartLock::ControlTypeSupport_var control_ts =
      new SmartLock::ControlTypeSupportImpl;

    if (control_ts->register_type(participant, "") != DDS::RETCODE_OK) {
      ACE_ERROR_RETURN((LM_ERROR,
                        ACE_TEXT("ERROR: %N:%l: main() -")
                        ACE_TEXT(" register_type failed!\n")),
                       -1);
    }

    // Create Topic
    // Status
    CORBA::String_var type_name = status_ts->get_type_name();
    DDS::Topic_var status_topic =
      participant->create_topic("SmartLock Status",
                                type_name,
                                TOPIC_QOS_DEFAULT,
                                0,
                                OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (!status_topic) {
      ACE_ERROR_RETURN((LM_ERROR,
                        ACE_TEXT("ERROR: %N:%l: main() -")
                        ACE_TEXT(" create_topic failed!\n")),
                       -1);
    }

    // Control
    type_name = control_ts->get_type_name();
    DDS::Topic_var control_topic =
      participant->create_topic("SmartLock Control",
                                type_name,
                                TOPIC_QOS_DEFAULT,
                                0,
                                OpenDDS::DCPS::DEFAULT_STATUS_MASK);

    if (!control_topic) {
      ACE_ERROR_RETURN((LM_ERROR,
                        ACE_TEXT("ERROR: %N:%l: main() -")
                        ACE_TEXT(" create_topic failed!\n")),
                       -1);
    }

    int retval = 0;
    switch (role) {
    case kUnknown:
      break;
    case kSmartLock:
#if defined(HAS_PIGPIO)
      pi_init();
      pi_clear();
#endif
      retval = run_smartlock(lock, groups, participant, status_topic, control_topic);
      break;
    case kUser:
      retval = run_user(lock.id(), groups, participant, status_topic, control_topic);
      break;
    case kDealer:
      std::cout << "TODO:  Implement logic for dealer" << std::endl;
      break;
    }

    cleanup();

    if (retval != 0) return retval;

  } catch (const CORBA::Exception& e) {
    e._tao_print_exception("Exception caught in main():");
    return -1;
  }

  return 0;
}
