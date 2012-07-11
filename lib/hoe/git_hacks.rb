class Hoe
  module Git_Hacks
    VERSION = '1.0.0'

    # https://github.com/jbarnette/hoe-git/pull/8
    def initialize_git_hacks
      task(:release_to).prerequisites.delete 'git:tag'
      task :postrelease => 'git:tag'
    end

    # https://github.com/jbarnette/hoe-git/pull/7
    def git_tags
      flags = "--date-order --simplify-by-decoration --pretty=format:%d"
      `git log #{flags}`.scan(%r{#{git_release_tag_prefix}[^,)]+}).reverse
    end

    def define_git_hacks_tasks
    end

  end if Hoe.plugins.include?(:git)
end
