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

          key =~ /\Asuperproject\.(?<name>.*)\.repo\z/
          raise "Invalid superproject key: #{key}" unless $LAST_MATCH_INFO

          name = $LAST_MATCH_INFO[:name]

          value =~ %r{\A[-\w]+/[-\w]+\z}
          raise "Invalid repo name: #{value}" unless $LAST_MATCH_INFO

          @superprojects[name] << value
        end
      end

      def list(name)
        @superprojects[name].to_a
      end

      def add(name, *repos)
        repos.each do |repo|
          @superprojects[name] << repo
        end
        @superprojects[name].to_a
      end

      def remove(name, *repos)
        repos.each do |repo|
          @superprojects[name].delete(repo)
        end
        @superprojects[name].to_a
      end

      def write_to(file)
        # create backup of original file
        FileUtils.mv(file, "#{file}~") if File.exist? file

        @superprojects.each do |name, repos|
          name = "superproject.#{name}.repo"
          repos.each do |repo|
            `git config --file #{file} --add #{name} #{repo}`
          end
        end

        # copy across all the comments from the original file
        `egrep '^# ' "#{file}~" >> "#{file}"`
      end

      def to_json
        @superprojects.to_json
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
