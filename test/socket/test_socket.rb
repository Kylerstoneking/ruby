begin
  require "socket"
  require "tmpdir"
  require "test/unit"
rescue LoadError
end

class TestSocket < Test::Unit::TestCase
  def test_socket_new
    s = Socket.new(:INET, :STREAM)
    assert_kind_of(Socket, s)
  end

  def test_unpack_sockaddr
    sockaddr_in = Socket.sockaddr_in(80, "")
    assert_raise(ArgumentError) { Socket.unpack_sockaddr_un(sockaddr_in) }
    sockaddr_un = Socket.sockaddr_un("/tmp/s")
    assert_raise(ArgumentError) { Socket.unpack_sockaddr_in(sockaddr_un) }
    assert_raise(ArgumentError) { Socket.unpack_sockaddr_in("") }
    assert_raise(ArgumentError) { Socket.unpack_sockaddr_un("") }
  end if Socket.respond_to?(:sockaddr_un)

  def test_sysaccept
    serv = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    serv.bind(Socket.sockaddr_in(0, "127.0.0.1"))
    serv.listen 5
    c = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    c.connect(serv.getsockname)
    fd, peeraddr = serv.sysaccept
    assert_equal(c.getsockname, peeraddr.to_sockaddr)
  ensure
    serv.close if serv
    c.close if c
    IO.for_fd(fd).close if fd
  end

  def test_initialize
    Socket.open(Socket::AF_INET, Socket::SOCK_STREAM, 0) {|s|
      addr = s.getsockname
      assert_nothing_raised { Socket.unpack_sockaddr_in(addr) }
      assert_raise(ArgumentError) { Socket.unpack_sockaddr_un(addr) }
    }
    Socket.open("AF_INET", "SOCK_STREAM", 0) {|s|
      addr = s.getsockname
      assert_nothing_raised { Socket.unpack_sockaddr_in(addr) }
      assert_raise(ArgumentError) { Socket.unpack_sockaddr_un(addr) }
    }
    Socket.open(:AF_INET, :SOCK_STREAM, 0) {|s|
      addr = s.getsockname
      assert_nothing_raised { Socket.unpack_sockaddr_in(addr) }
      assert_raise(ArgumentError) { Socket.unpack_sockaddr_un(addr) }
    }
  end

  def test_getaddrinfo
    # This should not send a DNS query because AF_UNIX.
    assert_raise(SocketError) { Socket.getaddrinfo("www.kame.net", 80, "AF_UNIX") }
  end

  def test_getnameinfo
    assert_raise(SocketError) { Socket.getnameinfo(["AF_UNIX", 80, "0.0.0.0"]) }
  end

  def test_ip_address_list
    begin
      list = Socket.ip_address_list
    rescue NotImplementedError
      return
    end
    list.each {|ai|
      assert_instance_of(AddrInfo, ai)
      assert(ai.ip?)
    }
  end

  def test_tcp
    TCPServer.open(0) {|serv|
      port, addr = Socket.unpack_sockaddr_in(serv.getsockname)
      Socket.tcp(addr, port) {|s1|
        s2 = serv.accept
        begin
          assert_equal(s2.remote_address.ip_unpack, s1.local_address.ip_unpack)
        ensure
          s2.close
        end
      }
    }
  end

  def random_port
    # IANA suggests dynamic port for 49152 to 65535
    # http://www.iana.org/assignments/port-numbers
    49152 + rand(65535-49152+1)
  end

  def test_tcp_server_sockets
    port = random_port
    begin
      sockets = Socket.tcp_server_sockets(port)
    rescue Errno::EADDRINUSE
      return # not test failure
    end
    begin
      sockets.each {|s|
        assert_equal(port, s.local_address.ip_port)
      }
    ensure
      sockets.each {|s|
        s.close
      }
    end
  end

  if defined? UNIXSocket
    def test_unix
      Dir.mktmpdir {|tmpdir|
        path = "#{tmpdir}/sock"
        UNIXServer.open(path) {|serv|
          Socket.unix(path) {|s1|
            s2 = serv.accept
            begin
              assert_equal(s2.remote_address.unix_path, s1.local_address.unix_path)
            ensure
              s2.close
            end
          }
        }
      }
    end

    def test_unix_server_socket
      Dir.mktmpdir {|tmpdir|
        path = "#{tmpdir}/sock"
        2.times {
          serv = Socket.unix_server_socket(path)
          begin
            assert_kind_of(Socket, serv)
            assert(File.socket?(path))
            assert_equal(path, serv.local_address.unix_path)
          ensure
            serv.close
          end
        }
      }
    end
  end

end if defined?(Socket)
