class Hilda::Log

  def initialize
    @log = []
  end

  def log!(*args)
    if args.first.is_a? LogMessage
      @log << args.first
    else
      @log << LogMessage.new(*args)
    end
  end

  def clear!
    @log = []
  end

  def errors?
    @log.any? do |log_message| log_message.level == :error end
  end

  def first_error_message
    (@log.find do |log_message| log_message.level == :error end).try(:message)
  end

  def self.parse(json)
    Hilda::Log.new.tap do |log|
      JSON.parse(json).each do |message|
        log.log!(LogMessage.parse(message))
      end
    end
  end

  def self.from_json(json)
    self.allocate.tap do |obj| obj.from_json(json) end
  end
  def from_json(json)
    json = JSON.parse(json) if json.is_a? String
    json = json.with_indifferent_access unless json.is_a? ActiveSupport::HashWithIndifferentAccess
    @log = json[:log].map do |message| LogMessage.from_json(message) end
  end
  def as_json(*args)
    { log: @log.map(&:as_json) }
  end

  def marshal_dump
    as_json
  end
  def marshal_load(hash)
    from_json(hash)
  end

  delegate :empty?, :any?, :select, :find, :each, :length, :size, :count, :first, :last, :map, to: :@log

  def to_a
    return @log
  end

  class LogMessage
    attr_reader :level, :message, :exception
    def initialize(*args)
      if args.count==1
        if args[0].is_a? Exception
          @exception = args[0]
          @message = @exception.to_s
          @level = :error
        else
          @message = args[0].to_s
          @level = :info
        end
      elsif args.count==2
        if args[1].is_a? Exception
          @message, @exception = args
          @level = :error
        else
          @level, @message = args
        end
      else
        @level, @message, @exception = args
      end
    end

    def to_s
      return @message if @level == :info
      "#{@level.to_s.upcase}: #{@message}"
    end

    def exception_as_json
      return nil unless exception
      { message: exception.to_s, backtrace: exception.backtrace }
    end

    def self.parse_exception(json)
      return nil if json.nil?
      return OpenStruct.new(message: json['message'] || json[:message], backtrace: json['backtrace'] || json[:backtrace])
    end

    def self.from_json(json)
      self.allocate.tap do |obj| obj.from_json(json) end
    end
    def from_json(json)
      json = JSON.parse(json) if json.is_a? String
      json = json.with_indifferent_access unless json.is_a? ActiveSupport::HashWithIndifferentAccess
      @level = json[:level].to_sym
      @message = json[:message]
      @exception = self.class.parse_exception(json[:exception])
    end

    def as_json(*args)
      {level: level, message: message, exception: exception_as_json}.compact
    end

    def self.parse(json)
      from_json(json)
    end

    def marshal_dump
      as_json
    end
    def marshal_load(json)
      from_json(json)
    end
  end

end
