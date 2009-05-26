require 'cerberus/utils'

class Cerberus::SCM::Git
  def initialize(path, config = {})
    raise "Path can't be nil" unless path

    @path, @config = path.strip, config
    @encoded_path = (@path.include?(' ') ? "\"#{@path}\"" : @path)
  end

  def installed?
    exec_successful? "#{@config[:bin_path]}git --version"
  end

  def update!
    if test(?d, @path + '/.git')
      get_updates
      execute("reset", "--hard #{remote_head}")
    else
      FileUtils.rm_rf(@path) if test(?d, @path)
      encoded_url = (@config[:scm, :url].include?(' ') ? "\"#{@config[:scm, :url]}\"" : @config[:scm, :url])
      @new = true
      @status = execute("clone", "#{encoded_url} #{@path}", false)
      if branch = @config[:scm, :branch]
        execute('branch', "--track #{branch} #{remote_head}")
        execute('checkout', branch)
      end
    end
  end

  def has_changes?
    extract_current_head_revision
    new? or ( last_tested_revision != @revision )
  end

  def new?
    @new == true
  end

  def current_revision
    @revision
  end

  def url
    @path
  end

  def last_commit_message
    @message
  end

  def last_author
    @author
  end

  def output
    @status
  end

  private
  
  def get_updates
    execute("fetch")
  end

  def remote_head
    branch = @config[:scm, :branch] 
    branch ? "origin/#{branch}" : "origin"
  end

  def execute(command, parameters = nil, with_path = true)
   if with_path
     cmd = "cd #{@config[:application_root]} && #{@config[:bin_path]}git --git-dir=#{@path}/.git #{command} #{parameters}"
   else
     cmd = "#{@config[:bin_path]}git #{command} #{parameters}"
   end
   puts cmd if @config[:verbose]
   `#{cmd}`
  end

  def extract_commit_info( commit=remote_head )
    message = execute("show", "#{ commit } --pretty='format:%an(%ae)|%ai|%H|%s'").split("|")
    { :author => message[0], :date => message[1], :revision => message[2], :message => message[3] }
  end

  def last_tested_revision
    # TODO Is there a better way to extract the last tested commit?
    app_name          = @config['application_name']
    app_root          = "#{Cerberus::HOME}/work/#{app_name}"
    status            = Cerberus::Status.new("#{app_root}/status.log")
    commit_info = extract_commit_info(status.revision)
    @last_tested_revision ||= commit_info[:revision]
  end

  def extract_current_head_revision
    commit_info = extract_commit_info
    @author     = commit_info[:author]
    @date       = commit_info[:date]
    @revision   = commit_info[:revision]
    @message    = commit_info[:message]
  end
end
