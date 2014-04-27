require 'test/unit'
require 'ipaddr'

class TC_IPAddr < Test::Unit::TestCase
  def test_s_new
    [
      ["3FFE:505:ffff::/48"],
      ["0:0:0:1::"],
      ["2001:200:300::/48"],
      ["2001:200:300::192.168.1.2/48"],
      ["1:2:3:4:5:6:7::"],
      ["::2:3:4:5:6:7:8"],
    ].each { |args|
      assert_nothing_raised {
        IPAddr.new(*args)
      }
    }

    a = IPAddr.new
    assert_equal("::", a.to_s)
    assert_equal("0000:0000:0000:0000:0000:0000:0000:0000", a.to_string)
    assert_equal(Socket::AF_INET6, a.family)

    a = IPAddr.new("0123:4567:89ab:cdef:0ABC:DEF0:1234:5678")
    assert_equal("123:4567:89ab:cdef:abc:def0:1234:5678", a.to_s)
    assert_equal("0123:4567:89ab:cdef:0abc:def0:1234:5678", a.to_string)
    assert_equal(Socket::AF_INET6, a.family)

    a = IPAddr.new("3ffe:505:2::/48")
    assert_equal("3ffe:505:2::", a.to_s)
    assert_equal("3ffe:0505:0002:0000:0000:0000:0000:0000", a.to_string)
    assert_equal(Socket::AF_INET6, a.family)
    assert_equal(false, a.ipv4?)
    assert_equal(true, a.ipv6?)
    assert_equal("#<IPAddr: IPv6:3ffe:0505:0002:0000:0000:0000:0000:0000/ffff:ffff:ffff:0000:0000:0000:0000:0000>", a.inspect)

    a = IPAddr.new("3ffe:505:2::/ffff:ffff:ffff::")
    assert_equal("3ffe:505:2::", a.to_s)
    assert_equal("3ffe:0505:0002:0000:0000:0000:0000:0000", a.to_string)
    assert_equal(Socket::AF_INET6, a.family)

    a = IPAddr.new("0.0.0.0")
    assert_equal("0.0.0.0", a.to_s)
    assert_equal("0.0.0.0", a.to_string)
    assert_equal(Socket::AF_INET, a.family)

    a = IPAddr.new("192.168.1.2")
    assert_equal("192.168.1.2", a.to_s)
    assert_equal("192.168.1.2", a.to_string)
    assert_equal(Socket::AF_INET, a.family)
    assert_equal(true, a.ipv4?)
    assert_equal(false, a.ipv6?)

    a = IPAddr.new("192.168.1.2/24")
    assert_equal("192.168.1.0", a.to_s)
    assert_equal("192.168.1.0", a.to_string)
    assert_equal(Socket::AF_INET, a.family)
    assert_equal("#<IPAddr: IPv4:192.168.1.0/255.255.255.0>", a.inspect)

    a = IPAddr.new("192.168.1.2/255.255.255.0")
    assert_equal("192.168.1.0", a.to_s)
    assert_equal("192.168.1.0", a.to_string)
    assert_equal(Socket::AF_INET, a.family)

    assert_equal("0:0:0:1::", IPAddr.new("0:0:0:1::").to_s)
    assert_equal("2001:200:300::", IPAddr.new("2001:200:300::/48").to_s)

    assert_equal("2001:200:300::", IPAddr.new("[2001:200:300::]/48").to_s)
    assert_equal("1:2:3:4:5:6:7:0", IPAddr.new("1:2:3:4:5:6:7::").to_s)
    assert_equal("0:2:3:4:5:6:7:8", IPAddr.new("::2:3:4:5:6:7:8").to_s)

    assert_raise(IPAddr::InvalidAddressError) { IPAddr.new("192.168.0.256") }
    assert_raise(IPAddr::InvalidAddressError) { IPAddr.new("192.168.0.011") }
    assert_raise(IPAddr::InvalidAddressError) { IPAddr.new("fe80::1%fxp0") }
    assert_raise(IPAddr::InvalidAddressError) { IPAddr.new("[192.168.1.2]/120") }
    assert_raise(IPAddr::InvalidPrefixError) { IPAddr.new("::1/255.255.255.0") }
    assert_raise(IPAddr::InvalidPrefixError) { IPAddr.new("::1/129") }
    assert_raise(IPAddr::InvalidPrefixError) { IPAddr.new("192.168.0.1/33") }
    assert_raise(IPAddr::AddressFamilyError) { IPAddr.new(1) }
    assert_raise(IPAddr::AddressFamilyError) { IPAddr.new("::ffff:192.168.1.2/120", Socket::AF_INET) }
  end

  def test_s_new_ntoh
    addr = ''
    IPAddr.new("1234:5678:9abc:def0:1234:5678:9abc:def0").hton.each_byte { |c|
      addr += sprintf("%02x", c)
    }
    assert_equal("123456789abcdef0123456789abcdef0", addr)
    addr = ''
    IPAddr.new("123.45.67.89").hton.each_byte { |c|
      addr += sprintf("%02x", c)
    }
    assert_equal(sprintf("%02x%02x%02x%02x", 123, 45, 67, 89), addr)
    a = IPAddr.new("3ffe:505:2::")
    assert_equal("3ffe:505:2::", IPAddr.new_ntoh(a.hton).to_s)
    a = IPAddr.new("192.168.2.1")
    assert_equal("192.168.2.1", IPAddr.new_ntoh(a.hton).to_s)
  end

  def test_ipv4_compat
    a = IPAddr.new("::192.168.1.2")
    assert_equal("::192.168.1.2", a.to_s)
    assert_equal("0000:0000:0000:0000:0000:0000:c0a8:0102", a.to_string)
    assert_equal(Socket::AF_INET6, a.family)
    assert_equal(true, a.ipv4_compat?)
    b = a.native
    assert_equal("192.168.1.2", b.to_s)
    assert_equal(Socket::AF_INET, b.family)
    assert_equal(false, b.ipv4_compat?)

    a = IPAddr.new("192.168.1.2")
    b = a.ipv4_compat
    assert_equal("::192.168.1.2", b.to_s)
    assert_equal(Socket::AF_INET6, b.family)
  end

  def test_ipv4_mapped
    a = IPAddr.new("::ffff:192.168.1.2")
    assert_equal("::ffff:192.168.1.2", a.to_s)
    assert_equal("0000:0000:0000:0000:0000:ffff:c0a8:0102", a.to_string)
    assert_equal(Socket::AF_INET6, a.family)
    assert_equal(true, a.ipv4_mapped?)
    b = a.native
    assert_equal("192.168.1.2", b.to_s)
    assert_equal(Socket::AF_INET, b.family)
    assert_equal(false, b.ipv4_mapped?)

    a = IPAddr.new("192.168.1.2")
    b = a.ipv4_mapped
    assert_equal("::ffff:192.168.1.2", b.to_s)
    assert_equal(Socket::AF_INET6, b.family)
  end

  def test_reverse
    assert_equal("f.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.2.0.0.0.5.0.5.0.e.f.f.3.ip6.arpa", IPAddr.new("3ffe:505:2::f").reverse)
    assert_equal("1.2.168.192.in-addr.arpa", IPAddr.new("192.168.2.1").reverse)
  end

  def test_ip6_arpa
    assert_equal("f.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.2.0.0.0.5.0.5.0.e.f.f.3.ip6.arpa", IPAddr.new("3ffe:505:2::f").ip6_arpa)
    assert_raise(IPAddr::InvalidAddressError) {
      IPAddr.new("192.168.2.1").ip6_arpa
    }
  end

  def test_ip6_int
    assert_equal("f.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.2.0.0.0.5.0.5.0.e.f.f.3.ip6.int", IPAddr.new("3ffe:505:2::f").ip6_int)
    assert_raise(IPAddr::InvalidAddressError) {
      IPAddr.new("192.168.2.1").ip6_int
    }
  end

  def test_to_s
    assert_equal("3ffe:0505:0002:0000:0000:0000:0000:0001", IPAddr.new("3ffe:505:2::1").to_string)
    assert_equal("3ffe:505:2::1", IPAddr.new("3ffe:505:2::1").to_s)
  end

  def test_unmasked_addr
    feature = '[GH-599]'
    assert_equal('192.168.1.100', IPAddr.new('192.168.1.100/24').unmasked_addr, feature)
  end
end

class TC_Operator < Test::Unit::TestCase

  IN6MASK32  = "ffff:ffff::"
  IN6MASK128 = "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"

  def setup
    @in6_addr_any = IPAddr.new()
    @a = IPAddr.new("3ffe:505:2::/48")
    @b = IPAddr.new("0:0:0:1::")
    @c = IPAddr.new(IN6MASK32)
  end
  alias set_up setup

  def test_or
    assert_equal("3ffe:505:2:1::", (@a | @b).to_s)
    a = @a
    a |= @b
    assert_equal("3ffe:505:2:1::", a.to_s)
    assert_equal("3ffe:505:2::", @a.to_s)
    assert_equal("3ffe:505:2:1::",
                 (@a | 0x00000000000000010000000000000000).to_s)
  end

  def test_and
    assert_equal("3ffe:505::", (@a & @c).to_s)
    a = @a
    a &= @c
    assert_equal("3ffe:505::", a.to_s)
    assert_equal("3ffe:505:2::", @a.to_s)
    assert_equal("3ffe:505::", (@a & 0xffffffff000000000000000000000000).to_s)
  end

  def test_shift_right
    assert_equal("0:3ffe:505:2::", (@a >> 16).to_s)
    a = @a
    a >>= 16
    assert_equal("0:3ffe:505:2::", a.to_s)
    assert_equal("3ffe:505:2::", @a.to_s)
  end

  def test_shift_left
    assert_equal("505:2::", (@a << 16).to_s)
    a = @a
    a <<= 16
    assert_equal("505:2::", a.to_s)
    assert_equal("3ffe:505:2::", @a.to_s)
  end

  def test_carrot
    a = ~@in6_addr_any
    assert_equal(IN6MASK128, a.to_s)
    assert_equal("::", @in6_addr_any.to_s)
  end

  def test_equal
    assert_equal(true, @a == IPAddr.new("3FFE:505:2::"))
    assert_equal(true, @a == IPAddr.new("3ffe:0505:0002::"))
    assert_equal(true, @a == IPAddr.new("3ffe:0505:0002:0:0:0:0:0"))
    assert_equal(false, @a == IPAddr.new("3ffe:505:3::"))
    assert_equal(true, @a != IPAddr.new("3ffe:505:3::"))
    assert_equal(false, @a != IPAddr.new("3ffe:505:2::"))
  end

  def test_mask
    a = @a.mask(32)
    assert_equal("3ffe:505::", a.to_s)
    assert_equal("3ffe:505:2::", @a.to_s)
  end

  def test_include?
    assert_equal(true, @a.include?(IPAddr.new("3ffe:505:2::")))
    assert_equal(true, @a.include?(IPAddr.new("3ffe:505:2::1")))
    assert_equal(false, @a.include?(IPAddr.new("3ffe:505:3::")))
    net1 = IPAddr.new("192.168.2.0/24")
    assert_equal(true, net1.include?(IPAddr.new("192.168.2.0")))
    assert_equal(true, net1.include?(IPAddr.new("192.168.2.255")))
    assert_equal(false, net1.include?(IPAddr.new("192.168.3.0")))
    # test with integer parameter
    int = (192 << 24) + (168 << 16) + (2 << 8) + 13

    assert_equal(true, net1.include?(int))
    assert_equal(false, net1.include?(int+255))

  end

  def test_hash
    a1 = IPAddr.new('192.168.2.0')
    a2 = IPAddr.new('192.168.2.0')
    a3 = IPAddr.new('3ffe:505:2::1')
    a4 = IPAddr.new('3ffe:505:2::1')
    a5 = IPAddr.new('127.0.0.1')
    a6 = IPAddr.new('::1')
    a7 = IPAddr.new('192.168.2.0/25')
    a8 = IPAddr.new('192.168.2.0/25')

    h = { a1 => 'ipv4', a2 => 'ipv4', a3 => 'ipv6', a4 => 'ipv6', a5 => 'ipv4', a6 => 'ipv6', a7 => 'ipv4', a8 => 'ipv4'}
    assert_equal(5, h.size)
    assert_equal('ipv4', h[a1])
    assert_equal('ipv4', h[a2])
    assert_equal('ipv6', h[a3])
    assert_equal('ipv6', h[a4])

    require 'set'
    s = Set[a1, a2, a3, a4, a5, a6, a7, a8]
    assert_equal(5, s.size)
    assert_equal(true, s.include?(a1))
    assert_equal(true, s.include?(a2))
    assert_equal(true, s.include?(a3))
    assert_equal(true, s.include?(a4))
    assert_equal(true, s.include?(a5))
    assert_equal(true, s.include?(a6))
  end
end
