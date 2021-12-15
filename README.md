# DirectSockets

**A light-weight high-performance UDP sockets library.**

## Background

The Julia standard library `Sockets` provides a great `UDPSocket` implementation that wraps the `libuv` UDP socket interface and makes it work nicely with Julia's task system. This ensures that the thread pool used by Julia for multi-threading is freed up for use by other tasks, when a task blocks on a UDP `recv()` or `recvfrom()` call. This is the behavior that you'd mostly want, and exactly what the standard library provides.

However, the default `UDPSocket` implementation is unsuitable for use in data streaming applications when the UDP traffic is high for a few reasons:

1. The `recv()` and `recvfrom()` calls allocate receive buffers for each incoming packet. This leads to significant garbage collection load at high traffic.
2. At high loads, it is desirable for a thread to be dedicated to the receiving task, rather than being freed up for other tasks to use when the UDP socket blocks on receive.
3. The additional overhead from `libuv` in wrapping the system UDP calls is undesirable at high loads.

## Introduction

This `DirectSockets` library wraps the system UDP calls to provide an interface that is consistent with the `Sockets` standard library. This allows `DirectSockets.UDPSocket` to be used as a drop-in replacement for `Sockets.UDPSocket` in applications that demand high throughput, and do not mind having a receiving thread be dedicated for UDP data streaming.

Key features of `DirectSockets`:

- Drop-in replacement for `Sockets.UDPSocket()` with same API.
- Mutating `recv!()` method to support zero-allocation receive.
- No-overhead system UDP calls that help avoid the overhead of task scheduling and `libuv` in high-throughput UDP applications.

## Usage

The usage of `DirectSockets` is simple. Just use `DirectSockets.UDPSocket()` in place of `Sockets.UDPSocket()` to create a UDP socket:

```julia
using Sockets
using DirectSockets

sock = DirectSockets.UDPSocket()
```

You may then use the `bind()`, `send()`, `recv()`, `recvfrom()` and `close()` methods with the `sock`, just as you would with any `Sockets.UDPSocket()`. Additionally, `DirectSockets` provides a non-allocating (mutating) version `recv!(sock, buf)` that enables implementation of non-allocating receive loops:

```julia
try
  bind(sock, ip"0.0.0.0", 9000)
  buf = Vector{UInt8}(undef, DirectSockets.BUFSIZE)
  while true
    n = recv!(sock, buf)
    n < 0 && break
    # do something with the first n bytes of buf
  end
finally
  close(sock)
end
```

## Examples

Consider two simple functions that read a number of packets from a UDP socket and return the total number of bytes received:

```julia
using Sockets
using DirectSockets

function udpdemo1(m)
  sock = Sockets.UDPSocket()
  try
    bind(sock, ip"0.0.0.0", 9000)
    n = 0
    for i ∈ 1:m
      n += length(recv(sock))
    end
    n
  finally
    close(sock)
  end
end

function udpdemo2(m)
  sock = DirectSockets.UDPSocket()
  buf = Vector{UInt8}(undef, DirectSockets.BUFSIZE)
  try
    bind(sock, ip"0.0.0.0", 9000)
    n = 0
    for i ∈ 1:m
      n += recv!(sock, buf)
    end
    n
  finally
    close(sock)
  end
end
```

The function `udpdemo1()` uses the `Sockets.UDPSocket` and the allocating `recv()` call. The function `udpdemo2()` uses `DirectSockets.UDPSocket` and the non-allocating `recv!()` call instead.

We run each of these and generate traffic from a shell with:
```sh
cat /dev/random | nc -u 127.0.0.1 9000
```

Sample outputs from each of the functions show the memory allocation advantage at high throughput from `udpdemo2()`:

```julia
julia> @time udpdemo1(1000000)
  6.168455 seconds (6.00 M allocations: 1.132 GiB, 0.52% gc time)
1024000000

julia> @time udpdemo2(1000000)
  3.523687 seconds (2 allocations: 1.672 KiB)
1024000000
```

Note that the time in seconds isn't relevant here, as we manually ran the UDP load generator after starting the receiver function, and so there is some variability in the delay between the two. The key point here is the difference in memory allocation and garbage collection between the two implementations.
