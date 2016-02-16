require "./spec_helper"

describe "MessagePack serialization" do
  describe "from_msgpack" do
    it "does Array(Nil)#from_msgpack" do
      Array(Nil).from_msgpack(UInt8[146, 192, 192]).should eq([nil, nil])
    end

    it "does Array(Bool)#from_msgpack" do
      Array(Bool).from_msgpack(UInt8[146, 195, 194]).should eq([true, false])
    end

    it "does Array(Int32)#from_msgpack" do
      Array(Int32).from_msgpack(UInt8[147, 1, 2, 3]).should eq([1, 2, 3])
    end

    it "does Array(Int64)#from_msgpack" do
      Array(Int64).from_msgpack(UInt8[147, 1, 2, 3]).should eq([1, 2, 3])
    end

    it "does Array(Float32)#from_msgpack" do
      data = UInt8[147, 203, 63, 248, 0, 0, 0, 0, 0, 0, 2, 203, 64, 12, 0, 0, 0, 0, 0, 0]
      Array(Float32).from_msgpack(data).should eq([1.5, 2.0, 3.5])
    end

    it "does Array(Float64)#from_msgpack" do
      data = UInt8[147, 203, 63, 248, 0, 0, 0, 0, 0, 0, 2, 203, 64, 12, 0, 0, 0, 0, 0, 0]
      Array(Float64).from_msgpack(data).should eq([1.5, 2, 3.5])
    end

    it "does Hash(String, String)#from_msgpack" do
      data = UInt8[130, 163, 102, 111, 111, 161, 120, 163, 98, 97, 114, 161, 121]
      Hash(String, String).from_msgpack(data).should eq({"foo" => "x", "bar" => "y"})
    end

    it "does Hash(String, Int32)#from_msgpack" do
      data = UInt8[130, 163, 102, 111, 111, 1, 163, 98, 97, 114, 2]
      Hash(String, Int32).from_msgpack(data).should eq({"foo" => 1, "bar" => 2})
    end

    it "does Hash(String, Int32)#from_msgpack and skips null" do
      data = UInt8[131, 163, 102, 111, 111, 1, 163, 98, 97, 114, 2, 163, 98, 97, 122, 192]
      Hash(String, Int32).from_msgpack(data).should eq({"foo" => 1, "bar" => 2})
    end

    it "does Hash(Array(Int32), Int32)#from_msgpack and skips null" do
      data = UInt8[130, 147, 1, 2, 3, 1, 145, 2, 2]
      Hash(Array(Int32), Int32).from_msgpack(data).should eq({[1, 2, 3] => 1, [2] => 2})
    end

    it "does for Array(Int32) from IO" do
      io = MemoryIO.new
      io.write_byte(147.to_u8); io.write_byte(1.to_u8); io.write_byte(2.to_u8); io.write_byte(3.to_u8)
      io.rewind
      Array(Int32).from_msgpack(io).should eq([1, 2, 3])
    end

    it "does for Array(Int32) with block" do
      elements = [] of Int32
      Array(Int32).from_msgpack(UInt8[147, 1, 2, 3]) do |element|
        elements << element
      end
      elements.should eq([1, 2, 3])
    end

    it "does for tuple" do
      data = UInt8[146, 1, 165, 104, 101, 108, 108, 111]
      tuple = Tuple(Int32, String).from_msgpack(data)
      tuple.should eq({1, "hello"})
      tuple.should be_a(Tuple(Int32, String))
    end
  end

  describe "to_msgpack" do
    it "does for Nil" do
      nil.to_msgpack.should eq as_slice(UInt8[192])
    end

    it "does for Bool" do
      true.to_msgpack.should eq as_slice(UInt8[195])
    end

    it "does for Int32" do
      1.to_msgpack.should eq as_slice(UInt8[1])
    end

    it "does for Float64" do
      1.5.to_msgpack.should eq as_slice(UInt8[203, 63, 248, 0, 0, 0, 0, 0, 0])
    end

    it "does for String" do
      "hello".to_msgpack.should eq as_slice(UInt8[165, 104, 101, 108, 108, 111])
    end

    it "does for Array" do
      [1, 2, 3].to_msgpack.should eq as_slice(UInt8[147, 1, 2, 3])
    end

    it "does for Set" do
      Set(Int32).new([1, 1, 2]).to_msgpack.should eq as_slice(UInt8[146, 1, 2])
    end

    it "does for Hash" do
      {"foo" => 1, "bar" => 2}.to_msgpack.should eq as_slice(UInt8[130, 163, 102, 111, 111, 1, 163, 98, 97, 114, 2])
    end

    it "does for Hash with non-string keys" do
      {foo: 1, bar: 2}.to_msgpack.should eq as_slice(UInt8[130, 163, 102, 111, 111, 1, 163, 98, 97, 114, 2])
    end

    it "does for Hash with non-string keys" do
      {[1, 2, 3] => 1, [2] => 2}.to_msgpack.should eq as_slice(UInt8[130, 147, 1, 2, 3, 1, 145, 2, 2])
    end

    it "does for Tuple" do
      {1, "hello"}.to_msgpack.should eq as_slice(UInt8[146, 1, 165, 104, 101, 108, 108, 111])
    end

    it "nested data" do
      {"foo" => [1, 2, 3], "bar" => {"jo" => {1, :bla}}}.to_msgpack.should eq as_slice(UInt8[130, 163, 102, 111, 111, 147, 1, 2, 3, 163, 98, 97, 114, 129, 162, 106, 111, 146, 1, 163, 98, 108, 97])
    end

    it "Time" do
      msg = Time.new(1997, 11, 10, 0, 0, 0).to_msgpack(Time::Format.new("%F"))
      msg.should eq as_slice(UInt8[170, 49, 57, 57, 55, 45, 49, 49, 45, 49, 48])
      time = Time.from_msgpack(Time::Format.new("%F"), msg)
      time.should eq Time.new(1997, 11, 10, 0, 0, 0)
    end
  end

  describe "pack unpack" do
    it "array" do
      data = [1, 2, 3]
      typeof(data).from_msgpack(data.to_msgpack).should eq data
    end

    it "hash" do
      data = {"bla" => [1.1, 2.2], "zoo" => [111.11111]}
      typeof(data).from_msgpack(data.to_msgpack).should eq data
    end

    it "hash key not string" do
      data = {[1, 2, 3] => 1, [2] => 2}
      typeof(data).from_msgpack(data.to_msgpack).should eq data
    end

    it "tuple" do
      data = {"bla", 1, 1.5, true, nil}
      typeof(data).from_msgpack(data.to_msgpack).should eq data
    end

    it "mixed" do
      data = {"⬠ ⬡ ⬢ ⬣ ⬤ ⬥ ⬦" => {"bar" => true}, "zoo" => {"⬤" => false}}
      typeof(data).from_msgpack(data.to_msgpack).should eq data
    end

    it "ints" do
      data = Int64[1, -1, 0x21, -0x21, 128, -128, -0x8000, 0x8000, 0xFFFF, -0xFFFF, -0x80000000, 0x80000000, -9223372036854775808, 9223372036854775807, 4294967295, -4294967295]
      data.class.should eq(Array(Int64))
      data.to_msgpack.should eq(as_slice(UInt8[220, 0, 16, 1, 255, 33, 208, 223, 204, 128, 208, 128, 209, 128, 0, 205, 128, 0, 205, 255, 255, 210, 255, 255, 0, 1, 210, 128, 0, 0, 0, 206, 128, 0, 0, 0, 211, 128, 0, 0, 0, 0, 0, 0, 0, 207, 127, 255, 255, 255, 255, 255, 255, 255, 206, 255, 255, 255, 255, 211, 255, 255, 255, 255, 0, 0, 0, 1]))
      typeof(data).from_msgpack(data.to_msgpack).should eq data
    end

    it "uints" do
      data = UInt64[17223372036854775809]
      data.class.should eq(Array(UInt64))
      data.to_msgpack.should eq(as_slice(UInt8[145, 207, 239, 5, 181, 157, 59, 32, 0, 1]))
      typeof(data).from_msgpack(data.to_msgpack).should eq data
    end

  end
end
