#include "pigpio.h"
#include <ace/OS_NS_stdlib.h>
#include <ace/OS_NS_sys_socket.h>
#include <ace/OS_NS_arpa_inet.h>

static ACE_HANDLE sd = ACE_INVALID_HANDLE;


extern "C" {

int gpioInitialise()
{
  const char* pstr = ACE_OS::getenv("PIGPIO_PORT");
  const short port = pstr == 0 ? 4746 : ACE_OS::atoi(pstr);

  sd = ACE_OS::socket(AF_INET, SOCK_STREAM, 0);
  if (sd != ACE_INVALID_HANDLE) {
    struct sockaddr_in serv_addr;
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    ACE_OS::inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr);
    return ACE_OS::connect(sd,
                          (struct sockaddr*)&serv_addr,
                          sizeof(serv_addr));
  }
  return -1;
}

int gpioWrite(unsigned char line, unsigned char value)
{
  if (sd != ACE_INVALID_HANDLE) {
    const unsigned char buffer[] = { line, value };
    return ACE_OS::send(sd, reinterpret_cast<const char*>(buffer),
                        sizeof(buffer), 0);
  }
  return 0;
}

int gpioSetMode(unsigned char line, unsigned char mode)
{
  return 0;
}

int gpioTerminate()
{
  return ACE_OS::closesocket(sd);
}

}
