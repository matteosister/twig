require 'optparse'

class Twig
  module Cli

    def help_intro
      version_string = "Twig v#{Twig::VERSION}"

      <<-BANNER.gsub(/^[ ]+/, '')

        #{version_string}
        #{'-' * version_string.size}

        Twig tracks ticket ids, tasks, and other metadata for your Git branches.
        https://github.com/rondevera/twig

      BANNER
    end

    def help_separator(option_parser, text)
      option_parser.separator "\n#{text}\n\n"
    end

    def help_description(text, options={})
      width = options[:width] || 80
      text  = text.dup

      # Split into lines
      lines = []
      until text.empty?
        if text.size > width
          split_index = text[0..width].rindex(' ') || width
          lines << text.slice!(0, split_index)
          text.strip!
        else
          lines << text.slice!(0..-1)
        end
      end

      lines + [' '] # Add a blank line
    end

    def read_cli_options(args)
      option_parser = OptionParser.new do |opts|
        opts.banner         = help_intro
        opts.summary_indent = ' ' * 2
        opts.summary_width  = 32
        desc_width          = 40



        help_separator(opts, 'Common options:')

        desc = 'Use a specific branch.'
        opts.on('-b BRANCH', '--branch BRANCH', desc) do |branch|
          set_option(:branch, branch)
        end

        desc = 'Unset a branch property.'
        opts.on('--unset PROPERTY', desc) do |property_name|
          set_option(:unset_property, property_name)
        end

        desc = 'Show this help content.'
        opts.on('--help', desc) do
          puts opts; exit
        end

        desc = 'Show Twig version.'
        opts.on('--version', desc) do
          puts Twig::VERSION; exit
        end



        help_separator(opts, 'Filtering branches:')

        desc = help_description(
          'Only list branches whose name matches a given pattern.',
          :width => desc_width
        )
        opts.on('--only-branch PATTERN', *desc) do |pattern|
          set_option(:branch_only, pattern)
        end

        desc = help_description(
          'Do not list branches whose name matches a given pattern.',
          :width => desc_width
        )
        opts.on('--except-branch PATTERN', *desc) do |pattern|
          set_option(:branch_except, pattern)
        end

        desc = help_description(
          'Only list branches below a given age.', :width => desc_width
        )
        opts.on('--max-days-old AGE', *desc) do |age|
          set_option(:max_days_old, age)
        end

        desc = help_description(
          'Lists all branches regardless of age or name options. ' +
          'Useful for overriding options in ' +
          File.basename(Twig::Options::CONFIG_FILE) + '.',
          :width => desc_width
        )
        opts.on('--all', *desc) do |pattern|
          unset_option(:max_days_old)
          unset_option(:branch_except)
          unset_option(:branch_only)
        end



        help_separator(opts, 'Deprecated:')

        desc = 'Deprecated. Use `--only-branch` instead.'
        opts.on('--only-name PATTERN', desc) do |pattern|
          puts "\n`--only-name` is deprecated. Please use `--only-branch` instead.\n"
          set_option(:branch_only, pattern)
        end

        desc = 'Deprecated. Use `--except-branch` instead.'
        opts.on('--except-name PATTERN', desc) do |pattern|
          puts "\n`--except-name` is deprecated. Please use `--except-branch` instead.\n"
          set_option(:branch_except, pattern)
        end
      end

      option_parser.parse!(args)
    end

    def read_cli_args(args)
      branch_name = options[:branch] || current_branch_name
      property_to_unset = options.delete(:unset_property)

      if args.any?
        property_name, property_value = args[0], args[1]

        # Run command binary, if any, and exit here
        command_path = Twig.run("which twig-#{property_name}")
        exec(command_path) unless command_path.empty?

        # Get/set branch property
        if property_value
          # `$ twig <key> <value>`
          puts set_branch_property(branch_name, property_name, property_value)
        else
          # `$ twig <key>`
          value = get_branch_property(branch_name, property_name)
          if value && !value.empty?
            puts value
          else
            puts %{The branch "#{branch_name}" does not have the property "#{property_name}".}
          end
        end
      elsif property_to_unset
        # `$ twig --unset <key>`
        puts unset_branch_property(branch_name, property_to_unset)
      else
        # `$ twig`
        puts list_branches
      end
    end

  end
end
