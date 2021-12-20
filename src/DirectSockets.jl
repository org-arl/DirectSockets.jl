module DirectSockets

export recv!

using Sockets: Sockets, IPAddr, InetAddr, IPv4, send, recv, recvfrom

### constants (based on socket.h)

const AF_INET = Cint(2)
const SOCK_DGRAM = Cint(2)
const WAITALL = Cint(0x40)
const BUFSIZE = 1500

### interface

"UDP socket (without libuv)."
struct UDPSocket
  handle::Cint
end

"""
    UDPSocket()

Open a UDP socket (without libuv).
"""
UDPSocket() = UDPSocket(ccall(:socket, Cint, (Cint, Cint, Cint), AF_INET, SOCK_DGRAM, 0))

"""
    close(socket::DirectSockets.UDPSocket)

Close a UDP socket.
"""
function Base.close(sock::UDPSocket)
  ccall(:close, Cint, (Cint,), sock.handle)
  nothing
end

"""
    bind(socket::DirectSockets.UDPSocket, host::IPAddr, port::Integer)
    bind(socket::DirectSockets.UDPSocket, host_port::InetAddr)

Bind UDP socket to the given host:port. Note that 0.0.0.0 will listen on all devices.
"""
function Base.bind(sock::UDPSocket, host::IPAddr, port::Integer)
  0 ≤ port ≤ 65535 || throw(ArgumentError("port must be in the range 0-65535"))
  sockaddr = _sockaddr(host.host, port)
  ccall(:bind, Cint, (Cint, Ptr{Cvoid}, UInt32), sock.handle, sockaddr, length(sockaddr)) == 0
end

Base.bind(sock::UDPSocket, host_port::InetAddr) = bind(sock, host_port.host, host_port.port)

"""
    send(socket::DirectSockets.UDPSocket, host::IPAddr, port::Integer, msg::AbstractVector{UInt8})
    send(socket::DirectSockets.UDPSocket, host_port::InetAddr, msg::AbstractVector{UInt8})

Send `msg` over `socket` to `host:port`.
"""
function Sockets.send(sock::UDPSocket, host::IPAddr, port::Integer, msg::AbstractVector{UInt8})
  sockaddr = _sockaddr(host.host, port)
  ccall(:sendto, Cssize_t, (Cint, Ptr{Cvoid}, Csize_t, Cint, Ptr{Cvoid}, UInt32),
    sock.handle, msg, length(msg), 0, sockaddr, length(sockaddr)) == length(msg)
end

Sockets.send(sock::UDPSocket, host_port::InetAddr{IPv4}, msg::AbstractVector{UInt8}) = send(sock, host_port.host, host_port.port, msg)

"""
    recv(socket::DirectSockets.UDPSocket)

Read a UDP packet from the specified socket, and return the bytes received. This call blocks.
"""
function Sockets.recv(sock::UDPSocket)
  data = zeros(UInt8, BUFSIZE)
  n = ccall(:recvfrom, Cssize_t, (Cint, Ptr{Cvoid}, Csize_t, Cint, Ptr{Cvoid}, Ptr{UInt32}),
    sock.handle, data, length(data), WAITALL, Ptr{UInt8}(0), Ptr{UInt8}(0))
  n < 0 && throw(ErrorException("Socket unavailable"))
  resize!(data, n)
  data
end

"""
    recv!(socket::DirectSockets.UDPSocket, data::Vector{UInt8})

Read a UDP packet from the specified socket into a specified `data` buffer. If the buffer
is too small for the data, the received data may be truncated. This call blocks.
Returns the number of bytes read into the buffer, or a negative error code on error.
"""
function recv!(sock::UDPSocket, data::Vector{UInt8})
  ccall(:recvfrom, Cssize_t, (Cint, Ptr{Cvoid}, Csize_t, Cint, Ptr{Cvoid}, Ptr{UInt32}),
    sock.handle, data, length(data), WAITALL, Ptr{UInt8}(0), Ptr{UInt8}(0))
end

"""
    recvfrom(socket::DirectSockets.UDPSocket) -> (host_port, data)

Read a UDP packet from the specified socket, returning a tuple of `(host_port, data)`,
where `host_port` will be an `InetAddr{IPv4}` and `data` will be a `Vector{UInt8}`.
This call blocks.
"""
function Sockets.recvfrom(sock::UDPSocket)
  data = zeros(UInt8, BUFSIZE)
  sockaddr = zeros(UInt8, 16)
  sockaddr_len = Ref(UInt32(16))
  n = ccall(:recvfrom, Cssize_t, (Cint, Ptr{Cvoid}, Csize_t, Cint, Ptr{Cvoid}, Ptr{UInt32}),
    sock.handle, data, length(data), WAITALL, sockaddr, sockaddr_len)
  n < 0 && throw(ErrorException("Socket unavailable"))
  resize!(data, n)
  (sockaddr_len[] ≥ 8 && sockaddr[2] == AF_INET) || throw(ErrorException("Socket address unavailable"))
  InetAddr(IPv4(sockaddr[5:8]...), sockaddr[3] * 256 + sockaddr[4]), data
end

# TODO: support for ipv6
# TODO: setopt()

### helpers

struct sockaddr_in
  sin_family::Int16
  sin_port::UInt16
  in_addr::UInt32
  sin_zero::UInt64
end

# based on netinet/in.h
function _sockaddr(host, port)
  sockaddr = sockaddr_in(AF_INET, hton(UInt16(port)), hton(UInt32(host)), 0)
  reinterpret(UInt8, [sockaddr])
end

end # module
