using Sockets
using DirectSockets
using Test

@testset "DirectSockets" begin
  sock1 = DirectSockets.UDPSocket()
  sock2 = DirectSockets.UDPSocket()
  @test sock1 isa DirectSockets.UDPSocket
  @test sock2 isa DirectSockets.UDPSocket
  @test bind(sock1, ip"0.0.0.0", 9000)
  @test send(sock2, ip"127.0.0.1", 9000, UInt8[1,2,3,4])
  @test recv(sock1) == UInt8[1,2,3,4]
  @test send(sock2, ip"127.0.0.1", 9000, UInt8[5,6,7,8])
  buf = zeros(UInt8, DirectSockets.BUFSIZE)
  n = recv!(sock1, buf)
  @test n == 4
  @test buf[1:4] == UInt8[5,6,7,8]
  @test send(sock2, ip"127.0.0.1", 9000, UInt8[9,10,11,12])
  host_port, data = recvfrom(sock1)
  @test host_port isa Sockets.InetAddr{IPv4}
  @test data == UInt8[9,10,11,12]
  @test send(sock1, host_port, UInt8[13,14,15,16])
  @test recv(sock2) == UInt8[13,14,15,16]
  @test close(sock1) === nothing
  @test close(sock2) === nothing
  sock3 = DirectSockets.UDPSocket()
  @test bind(sock3, Sockets.InetAddr(ip"0.0.0.0", 9000))
  @test close(sock3) === nothing
  @test recv!(sock3, buf) < 0
  @test_throws ErrorException recv(sock3)
end
