require 'thread'
require_relative 'supervisor'
require_relative 'worker'

module LiveResource
  module Supervisor
    class ProcessSupervisor < WorkerSupervisor
      # Supervise a single process at the given path
      def add_process(name, path, options={}, &block)
        exp_path = File.expand_path(path)
        raise ArgumentError, "#{exp_path} does not exist." unless File.exists? exp_path
        raise ArgumentError, "#{exp_path} is not executable." unless File.executable? exp_path

        worker = ProcessWorker.new("#{name} (#{path})", exp_path, options, block)
        @events.push({type: :add_worker, worker: worker})
      end

      # Supervise all the processes in the given directory.
      def add_directory(name, path, options={}, &block)
        defaults = { pattern: /^.*$/ }
        options.merge!(defaults) { |key, v1, v2| v1 }

        exp_path = File.expand_path(path)
        raise ArgumentError, "#{exp_path} does not exist." unless File.exists? exp_path
        raise ArgumentError, "#{exp_path} is not a directory." unless File.directory? exp_path

        # Open up the directory and create workers for all the files which are executable and
        # match the user-specified pattern (if given).
        workers_added = false
        Dir.foreach(exp_path) do |file|
          exp_file = File.expand_path file, exp_path
          next if File.directory? exp_file or !File.executable? exp_file
          md = file.match options[:pattern]
          next unless md

          worker = ProcessWorker.new("#{name} (#{file})", exp_file, options, block)
          @events.push( {type: :add_worker, worker: worker})
          workers_added = true
        end

        unless workers_added
          raise ArgumentError,
            "No matching, executable workers in #{path} (pattern=#{options[:pattern]})."
        end
      end

      private

      def wait_loop
        loop do
          break if stopping? and !running_workers?

          # Check to see if any processes have died.
          begin
            pid = Process.waitpid -1, Process::WUNTRACED
          rescue SystemCallError
            # No more children?
            pid = nil
          end

          unless pid
            # Nothing to do, let another Thread run
            Thread.pass
            next
          end

          # look up worker
          worker = @workers.find { |w| w.pid == pid }

          if !worker
            raise RuntimeError, "Worker process (#{pid}) exited but no such worker found."
          end

          # Restart or suspend worker
          @events.push({type: :worker_exited, worker: worker})
        end
      end
    end
  end
end
