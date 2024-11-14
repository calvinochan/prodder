require 'cucumber'
require 'aruba/cucumber'

$LOAD_PATH.unshift File.expand_path('../../lib', File.dirname(__FILE__))
require 'prodder'

module ProdderHelpers
  def strip_leading(string)
    leading = string.scan(/^\s*/).min_by &:length
    string.gsub /^#{leading}/, ''
  end

  def in_workspace(name, &block)
    in_current_dir { Dir.chdir("prodder-workspace/#{name}", &block) }
  end

  def commit_to_remote(project)
    @dirs = ['tmp', 'aruba']
    run_simple "git clone repos/#{project}.git tmp-extra-commit-#{project}"
    cd "tmp-extra-commit-#{project}"

    append_to_file "README", 'Also read this!'
    run_simple 'git add README'
    run_simple 'git commit -m "Second commit"'
    run_simple "git push origin master"

    cd '..'
    run_simple "rm -rf tmp-extra-commit-#{project}"
  end

  def update_config(filename, &block)
    config = with_file_content(filename) do |contents|
      config = YAML.load contents
      block.call(config)
      config
    end

    write_file filename, config.to_yaml
  end

  def self.setup!
    puts '-------------- creating roles and databases --------------'
    pg = Prodder::PG.new
    pg.create_role 'prodder'
    pg.create_role 'include_this', ['--no-login']
    pg.create_role 'exclude_this'
    pg.create_role 'prodder__blog_prod:read_only', ['--no-login']
    pg.create_role 'prodder__blog_prod:read_write', ['--no-login']
    pg.create_role 'prodder__blog_prod:permissions_test:read_only', ['--no-login']
    pg.create_role 'prodder__blog_prod:permissions_test:read_write', ['--no-login']
    pg.create_role '_90enva', ['--no-login']
    pg.create_role '_91se', ['--no-login']
    pg.create_role '_91qa', ['--no-login']
    pg.create_role '_91b', ['--no-login']
    pg.create_role '_92b', ['--no-login']
    pg.create_role '_92se', ['--no-login']
    pg.create_role '_92qa', ['--no-login']
    pg.create_role '_93se', ['--no-login']
    pg.create_role '_93b', ['--no-login']
    pg.create_role '_94se', ['--no-login']

    fixture_dbs.each do |name, contents|
      pg.create_db name
      pg.psql name, "ALTER DEFAULT PRIVILEGES GRANT SELECT ON TABLES TO prodder;"
      pg.psql name, "ALTER DEFAULT PRIVILEGES GRANT SELECT ON SEQUENCES TO prodder;"
      pg.psql name, contents
    end
  end

  def self.teardown!
    pg = Prodder::PG.new
    fixture_dbs.each { |name, contents| pg.drop_db name }
    pg.drop_role 'prodder'
    pg.drop_role 'include_this'
    pg.drop_role 'exclude_this'
    pg.drop_role "prodder__blog_prod:read_only"
    pg.drop_role "prodder__blog_prod:read_write"
    pg.drop_role "prodder__blog_prod:permissions_test:read_only"
    pg.drop_role "prodder__blog_prod:permissions_test:read_write"
    pg.drop_role '_90enva'
    pg.drop_role '_91se'
    pg.drop_role '_91qa'
    pg.drop_role '_91b'
    pg.drop_role '_92se'
    pg.drop_role '_92b'
    pg.drop_role '_92qa'
    pg.drop_role '_93se'
    pg.drop_role '_93b'
    pg.drop_role '_94se'

  end

  def self.fixture_dbs
    @fixture_dbs ||= Dir[File.join(File.dirname(__FILE__), '*.sql')].map do |sql|
      db = File.basename(sql).sub('.sql', '')
      [db, File.read(sql)]
    end
  end
end

World ProdderHelpers

Before do
  @prodder_root = File.expand_path('../..', File.dirname(__FILE__))
  @aruba_root   = File.join(@prodder_root, 'tmp', 'aruba')
  @aruba_timeout_seconds = 10
  Dir.chdir @prodder_root
end

After('@restore-perms') do
  pg = Prodder::PG.new
  pg.psql 'prodder__blog_prod', "GRANT SELECT ON ALL TABLES IN SCHEMA public TO prodder;"
end

## Bootstrap the test role, databases, git repos.
ProdderHelpers.setup!
at_exit { ProdderHelpers.teardown! }
