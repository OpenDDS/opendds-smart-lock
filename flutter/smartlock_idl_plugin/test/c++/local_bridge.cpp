#define WIN32_LEAN_AND_MEAN
#include <ace/OS_NS_unistd.h>
#include <ace/Log_Msg.h>
#include "smartlock_idl_plugin.h"

int done = 0;
int ready = 0;

void notify(const char* message)
{
  ACE_DEBUG((LM_NOTICE, "(%P|%t) %s\n", message));
  ready = 1;
}

void updateLockStatus(const SmartLockStatus* status)
{
  ACE_DEBUG((LM_NOTICE, "(%P|%t) %s locked: %d\n", status->id, status->state == LOCKED ? true : false));
}

int ACE_TMAIN(int argc, ACE_TCHAR** argv)
{
  SmartLockStatus status;
  OpenDdsBridgeConfig config;
  OpenDdsBridge* bridge = createOpenDdsBridge();

  config.ini = "opendds_config.ini";
  config.id_ca = "certs/id_ca/identity_ca.pem";
  config.perm_ca = "certs/perm_ca/permissions_ca.pem";
  config.perm_gov = "certs/governance.xml.p7s";
  config.perm_perms = "certs/lock1/permissions.xml.p7s";
  config.id_cert = "certs/lock1/identity.pem";
  config.id_pkey = "certs/lock1/identity_key.pem";
  config.receiver = notify;
  config.update = updateLockStatus;

  startOpenDdsBridge(bridge, &config);
  while(!ready) {
    ACE_OS::sleep(1);
  }

  status.id = "lock1";
  status.state = LOCKED;
  status.enabled = 1;

  while(!done) {
    updateOpenDdsBridgeLockState(bridge, &status);
    ACE_OS::sleep(5);
  }

  shutdownOpenDdsBridge();
  destroyOpenDdsBridge(bridge);
  
  return 0;
}
