require "formula"
require "cli_parser"

module Homebrew
  module_function

  def bump_revision_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `bump-revision` [<options>] [<formula>]

        Create a commit to increment the revision of the formula. If no revision is
         present, "revision 1" will be added.
      EOS
      switch "-n", "--dry-run",
        description: "Print what would be done rather than doing it."
      switch "--write",
        depends_on:  "--dry-run",
        description: "When passed along with `--dry-run`, perform a not-so-dry run by making the expected "\
                     "file modifications but not taking any Git actions."
      flag   "--message=",
        description: "Append the provided <message> to the default PR message."

      switch :force
      switch :quiet
      switch :verbose
      switch :debug
    end
  end

  def bump_revision
    bump_revision_args.parse

    # As this command is simplifying user run commands then let's just use a
    # user path, too.
    ENV["PATH"] = ENV["HOMEBREW_PATH"]

    formula = ARGV.formulae.first
    current_revision = formula.revision

    if current_revision.zero?

      formula_spec = formula.stable
      hash_type, old_hash = if (checksum = formula_spec.checksum)
        [checksum.hash_type, checksum.hexdigest]
      end

      if hash_type
        # insert new revision after hash
        old = "#{hash_type} \"#{old_hash}\"\n"
      else
        # insert new revision after :revision
        old = ":revision => \"#{formula_spec.specs[:revision]}\"\n"
      end
      new = old + "  revision 1\n"
      if args.dry_run? && !args.write?
        ohai "replace #{old.inspect} with #{new.inspect}" unless Homebrew.args.quiet?
      else
        Utils::Inreplace.inreplace(formula.path) do |s|
          s.gsub!(old, new)
        end
      end

    else
      old = "revision #{current_revision}"
      new = "revision #{current_revision+1}"
      if args.dry_run? && !arg.write?
        ohai "replace #{old.inspect} with #{new.inspect}" unless Homebrew.args.quiet?
      else
        Utils::Inreplace.inreplace(formula.path) do |s|
          s.gsub!(old, new)
        end
      end
    end

    message = "#{formula.name}: revision bump #{args.message}"
    if args.dry_run?
      ohai "git commit --no-edit --verbose --message=#{message} -- #{formula.path}"
    else
      formula.path.parent.cd do
        safe_system "git", "commit", "--no-edit", "--verbose",
          "--message=#{message}", "--", formula.path
      end
    end
  end
end
