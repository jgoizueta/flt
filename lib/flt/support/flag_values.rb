module Flt
  module Support

    # This class assigns bit-values to a set of symbols
    # so they can be used as flags and stored as an integer.
    #   fv = FlagValues.new(:flag1, :flag2, :flag3)
    #   puts fv[:flag3]
    #   fv.each{|f,v| puts "#{f} -> #{v}"}
    class FlagValues

      #include Enumerator

      class InvalidFlagError < StandardError
      end
      class InvalidFlagTypeError < StandardError
      end


      # The flag symbols must be passed; values are assign in increasing order.
      #   fv = FlagValues.new(:flag1, :flag2, :flag3)
      #   puts fv[:flag3]
      def initialize(*flags)
        @flags = {}
        value = 1
        flags.each do |flag|
          raise InvalidFlagType,"Flags must be defined as symbols or classes; invalid flag: #{flag.inspect}" unless flag.kind_of?(Symbol) || flag.instance_of?(Class)
          @flags[flag] = value
          value <<= 1
        end
      end

      # Get the bit-value of a flag
      def [](flag)
        v = @flags[flag]
        raise InvalidFlagError, "Invalid flag: #{flag}" unless v
        v
      end

      # Return each flag and its bit-value
      def each(&blk)
        if blk.arity==2
          @flags.to_a.sort_by{|f,v|v}.each(&blk)
        else
          @flags.to_a.sort_by{|f,v|v}.map{|f,v|f}.each(&blk)
        end
      end

      def size
        @flags.size
      end

      def all_flags_value
        (1 << size) - 1
      end

    end

    # This class stores a set of flags. It can be assign a FlagValues
    # object (using values= or passing to the constructor) so that
    # the flags can be store in an integer (bits).
    class Flags

      class Error < StandardError
      end
      class InvalidFlagError < Error
      end
      class InvalidFlagValueError < Error
      end
      class InvalidFlagTypeError < Error
      end

      # When a Flag object is created, the initial flags to be set can be passed,
      # and also a FlagValues. If a FlagValues is passed an integer can be used
      # to define the flags.
      #    Flags.new(:flag1, :flag3, FlagValues.new(:flag1,:flag2,:flag3))
      #    Flags.new(5, FlagValues.new(:flag1,:flag2,:flag3))
      def initialize(*flags)
        @values = nil
        @flags = {}

        v = 0

        flags.flatten!

        flags.each do |flag|
          case flag
            when FlagValues
              @values = flag
            when Symbol, Class
              @flags[flag] = true
            when Integer
              v |= flag
            when Flags
              @values = flag.values
              @flags = flag.to_h.dup
            else
              raise InvalidFlagTypeError, "Invalid flag type for: #{flag.inspect}"
          end
        end

        if v!=0
          raise InvalidFlagTypeError, "Integer flag values need flag bit values to be defined" if @values.nil?
          self.bits = v
        end

        if @values
          # check flags
          @flags.each_key{|flag| check flag}
        end

      end

      def dup
        Flags.new(self)
      end

      # Clears all flags
      def clear!
        @flags = {}
      end

      # Sets all flags
      def set!
        if @values
          self.bits = @values.all_flags_value
        else
          raise Error,"No flag values defined"
        end
      end

      # Assign the flag bit values
      def values=(fv)
        @values = fv
      end

      # Retrieves the flag bit values
      def values
        @values
      end

      # Retrieves the flags as a bit-vector integer. Values must have been assigned.
      def bits
        if @values
          i = 0
          @flags.each do |f,v|
            bit_val = @values[f]
            i |= bit_val if v && bit_val
          end
          i
        else
          raise Error,"No flag values defined"
        end
      end

      # Sets the flags as a bit-vector integer. Values must have been assigned.
      def bits=(i)
        if @values
          raise Error, "Invalid bits value #{i}" if i<0 || i>@values.all_flags_value
          clear!
          @values.each do |f,v|
            @flags[f]=true if (i & v)!=0
          end
        else
          raise Error,"No flag values defined"
        end
      end

      # Retrieves the flags as a hash.
      def to_h
        @flags
      end

      # Same as bits
      def to_i
        bits
      end

      # Retrieve the setting (true/false) of a flag
      def [](flag)
        check flag
        @flags[flag]
      end

      # Modifies the setting (true/false) of a flag.
      def []=(flag,value)
        check flag
        case value
          when true,1
            value = true
          when false,0,nil
            value = false
          else
            raise InvalidFlagValueError, "Invalid value: #{value.inspect}"
        end
        @flags[flag] = value
        value
      end

      # Sets (makes true) one or more flags
      def set(*flags)
        flags = flags.first if flags.size==1 && flags.first.instance_of?(Array)
        flags.each do |flag|
          if flag.kind_of?(Flags)
            #if @values && other.values && compatible_values(other_values)
            #  self.bits |= other.bits
            #else
              flags.concat other.to_a
            #end
          else
            check flag
            @flags[flag] = true
          end
        end
      end

      # Clears (makes false) one or more flags
      def clear(*flags)
        flags = flags.first if flags.size==1 && flags.first.instance_of?(Array)
        flags.each do |flag|
          if flag.kind_of?(Flags)
            #if @values && other.values && compatible_values(other_values)
            #  self.bits &= ~other.bits
            #else
              flags.concat other.to_a
            #end
          else
            check flag
            @flags[flag] = false
          end
        end
      end

      # Sets (makes true) one or more flags (passes as an array)
      def << (flags)
        if flags.kind_of?(Array)
          set(*flags)
        else
          set(flags)
        end
      end

      # Iterate on each flag/setting pair.
      def each(&blk)
        if @values
          @values.each do |f,v|
            blk.call(f,@flags[f])
          end
        else
          @flags.each(&blk)
        end
      end

      # Iterate on each set flag
      def each_set
        each do |f,v|
          yield f if v
        end
      end

      # Iterate on each cleared flag
      def each_clear
        each do |f,v|
          yield f if !v
        end
      end

      # returns true if any flag is set
      def any?
        if @values
          bits != 0
        else
          to_a.size>0
        end
      end

      # Returns the true flags as an array
      def to_a
        a = []
        each_set{|f| a << f}
        a
      end

      def to_s
        "[#{to_a.map{|f| f.to_s.split('::').last}.join(', ')}]"
      end

      def inspect
        txt = "#{self.class.to_s}#{to_s}"
        txt << " (0x#{bits.to_s(16)})" if @values
        txt
      end


      def ==(other)
        if @values && other.values && compatible_values?(other.values)
          bits == other.bits
        else
          to_a.map{|s| s.to_s}.sort == other.to_a.map{|s| s.to_s}.sort
        end
      end



      private
      def check(flag)
        raise InvalidFlagType,"Flags must be defined as symbols or classes; invalid flag: #{flag.inspect}" unless flag.kind_of?(Symbol) || flag.instance_of?(Class)

        @values[flag] if @values # raises an invalid flag error if flag is invalid
        true
      end

      def compatible_values?(v)
        #@values.object_id==v.object_id
        @values == v
      end

    end

    module_function

    # Constructor for FlagValues
    def FlagValues(*params)
      if params.size==1 && params.first.kind_of?(FlagValues)
        params.first
      else
        FlagValues.new(*params)
      end
    end

    # Constructor for Flags
    def Flags(*params)
      if params.size==1 && params.first.kind_of?(Flags)
        params.first
      else
        Flags.new(*params)
      end
    end

  end
end

