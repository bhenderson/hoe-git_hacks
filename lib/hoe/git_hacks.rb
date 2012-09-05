class Hoe
  module Git_Hacks
    VERSION = '1.3.1'

    def define_git_hacks_tasks
      # https://github.com/jbarnette/hoe-git/pull/8
      task(:release_to).prerequisites.delete 'git:tag'
      task :postrelease => 'git:tag'

      desc 'Update the history file.'
      task 'prep_history' do
        update_history_file
      end

      desc "Commit latest changes."
      task "prep_release" do
        # opens $EDITOR with default message so user can preview what they are
        # committing.
        sh 'git commit -am"Preps for release." -ev'
      end

      # update the manifest and history files.
      task 'prep_release' => ['git:manifest', 'prep_history']
      # convenience tasks.
      file 'Manifest.txt' => 'git:manifest'
      file history_file   => 'prep_history'
    end

    # https://github.com/jbarnette/hoe-git/pull/7
    def git_tags
      flags = "--date-order --simplify-by-decoration --pretty=format:%d"
      `git log #{flags}`.scan(%r{#{git_release_tag_prefix}[^,)]+}).reverse
    end

    def update_history_file
      file = self.history_file
      data = File.read file

      return if data[%r'=== #{version} /']
      # append
      File.open file, 'w' do |f|
        write_latest_changelog f
        f.puts data
      end
    end

    def write_latest_changelog io
      begin
        stdout = STDOUT.clone
        STDOUT.reopen io
        ENV['FROM'] ||= git_tags.last
        ENV['VERSION'] ||= self.version

        task('git:changelog').invoke
      ensure
        STDOUT.reopen stdout
      end
    end

  end if Hoe.plugins.include?(:git)
end
