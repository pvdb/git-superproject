require 'git/superproject/version'

require 'set'
require 'json'
require 'English'
require 'pathname'
require 'fileutils'

module Git

  HOME                 = Pathname.new(Dir.home)
  GIT_MULTI_DIR        = HOME.join('.git', 'multi')
  SUPERPROJECTS_CONFIG = GIT_MULTI_DIR.join('superprojects.config')

  module Superproject
    class Error < StandardError; end

    class Config

      def self.from(file)
        new(
          `git config --file #{file} --list`
          .split($RS)
          .map(&:strip)
        )
      end

      def initialize(key_value_pairs)
        @superprojects = Hash.new do |superprojects, name|
          superprojects[name] = Set.new # guarantee uniqueness
        end

        key_value_pairs.each do |key_value|
          key, value = key_value.split('=')
          process(key, value)
        end
      end

      def list(name)
        @superprojects[name].to_a.sort
      end

      def add(name, *repos)
        repos.each do |repo|
          add_to(name, repo)
        end
        list(name)
      end

      def remove(name, *repos)
        repos.each do |repo|
          remove_from(name, repo)
        end
        list(name)
      end

      def write_to(file)
        # create backup of original file
        FileUtils.mv(file, "#{file}~") if File.exist? file

        @superprojects.keys.each do |name|
          key = "superproject.#{name}.repo"
          list(name).each do |repo|
            `git config --file #{file} --add #{key} #{repo}`
          end
        end

        # copy across all the comments from the original file
        `egrep '^# ' "#{file}~" >> "#{file}"`
      end

      def to_json
        @superprojects.to_json
      end

      private

      def process(key, repo)
        key =~ /\Asuperproject\.(?<name>.*)\.repo\z/
        raise "Invalid superproject key: #{key}" unless $LAST_MATCH_INFO

        add_to($LAST_MATCH_INFO[:name], repo)
      end

      def add_to(name, repo)
        repo =~ %r{\A[-.\w]+/[-.\w]+\z}
        raise "Invalid repo name: #{repo}" unless $LAST_MATCH_INFO

        @superprojects[name] << repo
      end

      def remove_from(name, repo)
        @superprojects[name].delete(repo)
      end

    end

    module Commands
      def self.version
        puts Git::Superproject::VERSION
      end

      def self.help
        puts 'git superproject ++bolt --list'
      end
    end
  end
end
