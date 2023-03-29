#include "smartlock_idl_plugin.h"
#include <string>

#include <dds/DCPS/Service_Participant.h>

#include <SmartLockTypeSupportImpl.h>

extern "C" {


class OpenDdsBridgeImpl
{
public:
  OpenDdsBridgeImpl()
   : secure(false),
     debug_level("3"),
     transport_debug_level("3"),
     DOMAIN(1),
     groups() {
  }

  void run() {
    startDds();
    try {
      initParticipant();
    }
    catch(const std::exception& e) {
    }
  }

  static void shutdown() {
  }

private:
  DDS::DataReaderQos newDefaultDataReaderQos(DDS::Subscriber_ptr subscriber) {
    DDS::DataReaderQos qos;
    subscriber->get_default_datareader_qos(qos);
    return qos;
  }

  DDS::PublisherQos newDefaultPublisherQos(
                      DDS::DomainParticipant_ptr participant) {
    DDS::PublisherQos qos;
    participant->get_default_publisher_qos(qos);
    return qos;
  }

  DDS::SubscriberQos newDefaultSubscriberQos(
                       DDS::DomainParticipant_ptr participant) {
    DDS::SubscriberQos qos;
    participant->get_default_subscriber_qos(qos);
    return qos;
  }

  void initParticipantFactory() {
    int argc = 0;
    participantFactory = TheParticipantFactoryWithArgs(argc, nullptr);
  }

  void startDds() {
  }

  void initParticipant() {
  }

  static const char* LOG_TAG;

  static DDS::DomainParticipantFactory_var participantFactory;
  static DDS::DomainParticipant_var participant;
  //static ParticipantLocationListener_var locationListener;
  static DDS::DataWriter_var dw;

  DDS::DomainParticipantQos particpantQos;

  bool secure;
  std::string debug_level;
  std::string transport_debug_level;
  int DOMAIN;
  std::vector<std::string> groups;
};

const char* OpenDdsBridgeImpl::LOG_TAG = "SmartLock_OpenDDS_Bridge";

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

void startOpenDdsBridge(OpenDdsBridge* bridge)
{
  if (bridge != nullptr) {
    reinterpret_cast<OpenDdsBridgeImpl*>(bridge->ptr)->run();
  }
}

void shutdownOpenDdsBridge() {
  OpenDdsBridgeImpl::shutdown();
}

}
