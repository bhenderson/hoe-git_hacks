class Hoe
  module Git_Hacks
    VERSION = '1.3.1'

    def define_git_hacks_tasks
      History.instance self

      # https://github.com/jbarnette/hoe-git/pull/8
      task(:release_to).prerequisites.delete 'git:tag'
      task :postrelease => 'git:tag'

      # overwrite default action
      task('git:changelog').clear_actions.enhance do
        History.write true
      end

      desc 'Update the history file.'
      task 'prep_history' do
        History.write
      end

      task("prep_release").prerequisites.delete 'version:bump'
      desc "Commit latest changes."
      task "prep_release" do
        # opens $EDITOR with default message so user can preview what they are
        # committing.
        sh 'git commit -am"Prep for release." -ev'
      end

      desc "Auto bump version based on git history."
      task 'git:version_bump' do
        version_task = "version:bump:#{History.version_bump}"
        if Rake::Task.task_defined? version_task
          task(version_task).invoke
        end
      end
      task :prep_history => 'git:version_bump'

      # update the manifest and history files.
      task 'prep_release' => ['git:manifest', 'prep_history']
      # convenience tasks.
      file 'Manifest.txt' => 'git:manifest'
      file history_file   => 'prep_history'
    end

    class History

      # most logic copied from hoe/git
      def self.write debug=false
        instance.write debug
      end

      def self.instance(spec=nil)
        @instance ||= new(spec)
      end

      def self.version_bump
        instance.version_bump
      end

      attr_reader :spec

      def initialize spec
        @spec = spec
        @changes = Hash.new { |h,k| h[k] = [] }
        @parsed_changes = false
      end

      def parse_changes
        return @changes if @parsed_changes
        @parsed_changes = true
        tag   = ENV["FROM"] || git_tags.last
        range = [tag, "HEAD"].compact.join ".."
        cmd   = "git log #{range} '--format=format:%s'"

        changes = `#{cmd}`.split("\n")

        return if changes.empty?

        changes.reverse!

        codes = {
          "!" => :major,
          "+" => :minor,
          "*" => :minor,
          "-" => :bug,
          "?" => :unknown,
        }

        codes_re = Regexp.escape codes.keys.join

        changes.each do |change|
          if change =~ /^\s*([#{codes_re}])\s*(.*)/ then
            code, line = codes[$1], $2
          else
            code, line = codes["?"], change.chomp
          end

          @changes[code] << line
        end

        @changes
      end

      def write debug
        if debug
          write_head $stdout
        else
          update
        end
      end

      def write_head io
        parse_changes
        now = Time.new.strftime "%Y-%m-%d"

        io.puts "=== #{ENV['VERSION'] || 'NEXT'} / #{now}"
        io.puts
        changelog_section io, :major
        changelog_section io, :minor
        changelog_section io, :bug
        changelog_section io, :unknown
        io.puts
      end

      def changelog_section io, code
        name = {
          :major   => "major enhancement",
          :minor   => "minor enhancement",
          :bug     => "bug fix",
          :unknown => "unknown",
        }[code]

        changes = @changes[code]
        count = changes.size
        name += "s" if count > 1
        name.sub!(/fixs/, 'fixes')

        return if count < 1

        io.puts "* #{count} #{name}:"
        io.puts
        changes.each do |line|
          io.puts "  * #{line}"
        end
        io.puts
      end

      def git_tags
        flags = "--date-order --all --simplify-by-decoration --pretty=format:%d"
        `git log #{flags}`.scan(%r{#{spec.git_release_tag_prefix}[^,)]+}).reverse
      end

      def update
        file = spec.history_file
        data = File.read file

        return if data[%r'=== #{spec.version} /']
        # append
        File.open file, 'w' do |f|
          write_head f
          f.puts data
        end
      end

      def version_bump
        parse_changes

        [:major, :minor].each do |level|
          return level unless @changes[level].empty?
        end

        return :patch
      end

    end

  end if Hoe.plugins.include?(:git)
end
