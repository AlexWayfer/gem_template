# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'open3'
require 'ffaker'

RSpec.describe 'Generated gem from template' do
	let(:gem_name) { 'foo-bar_baz' }

	let(:author_name) { FFaker::Name.name }
	let(:author_email) { FFaker::Internet.email }
	let(:namespace) { FFaker::Internet.user_name }

	let(:author_name_string) do
		quote = author_name.include?("'") ? '"' : "'"
		"#{quote}#{author_name}#{quote}"
	end

	before do
		system "git config user.name \"#{author_name}\""
		system "git config user.email \"#{author_email}\""

		Bundler.with_unbundled_env do
			## https://stackoverflow.com/a/25326622/2630849
			## https://stackoverflow.com/a/54626184/2630849
			Open3.popen3(
				"gem_generator #{gem_name} #{__dir__}/../template --namespace=#{namespace}"
			) do |stdin, _stdout, stderr, wait_thread|
				Thread.new do
					stderr.each { |l| puts l } unless stderr.closed?
				end

				stdin.puts 'Foo Bar Baz'
				stdin.close

				wait_thread.value
			end
		end

		Dir.chdir gem_name
	end

	after do
		Dir.chdir '..'

		FileUtils.rm_r gem_name

		system 'git config --unset user.name'
		system 'git config --unset user.email'
	end

	describe 'files' do
		let(:file_path) { self.class.description }

		describe 'content' do
			subject { File.read file_path }

			describe '.toys.rb' do
				let(:expected_lines) do
					[
						"require_relative 'lib/foo/bar_baz'"
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'README.md' do
				let(:expected_lines) do
					[
						'# Foo Bar Baz'
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'LICENSE.txt' do
				let(:expected_lines) do
					[
						"Copyright (c) #{Date.today.year} #{author_name}"
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'foo-bar_baz.gemspec' do
				let(:expected_lines) do
					[
						"spec.name        = 'foo-bar_baz'",
						'spec.version     = Foo::BarBaz::VERSION',
						"spec.authors     = [#{author_name_string}]",
						"spec.email       = ['#{author_email}']",
						"github_uri = \"https://github.com/#{namespace}/\#{spec.name}\""
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'lib/foo/bar_baz.rb' do
				let(:expected_lines) do
					[
						"require_relative 'bar_baz/version'"
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'spec/foo/bar_baz/version_spec.rb' do
				let(:expected_lines) do
					[
						"RSpec.describe 'Foo::BarBaz::VERSION' do"
					]
				end

				it { is_expected.to include_lines expected_lines }
			end
		end
	end

	describe 'outdated Node.js packages' do
		subject { system 'npm outdated' }

		it { is_expected.to be true }
	end

	describe 'outdated Ruby gems' do
		subject do
			system 'bundle outdated'
		end

		## https://github.com/deivid-rodriguez/pry-byebug/pull/346#issuecomment-817706135
		pending { is_expected.to be true }
	end

	describe 'Bundler audit' do
		subject do
			Bundler.with_unbundled_env do
				system 'bundle exec bundle-audit check --update'
			end
		end

		it { is_expected.to be true }
	end

	describe 'Remark lint' do
		subject do
			system 'npm run remark'
		end

		it { is_expected.to be true }
	end

	describe 'RuboCop lint' do
		subject do
			Bundler.with_unbundled_env do
				## `--config` is a hack for strange RuboCop behavior (no offenses when there are)
				system 'bundle exec rubocop --config .rubocop.yml'
			end
		end

		it { is_expected.to be true }
	end

	describe 'RSpec test' do
		subject do
			Bundler.with_unbundled_env do
				system 'bundle exec rspec'
			end
		end

		around do |example|
			## HACK: Don't try to send Codecov reports from generated project
			original_ci_value = ENV['CI']
			ENV['CI'] = nil
			example.run
			ENV['CI'] = original_ci_value
		end

		it { is_expected.to be true }
	end
end
