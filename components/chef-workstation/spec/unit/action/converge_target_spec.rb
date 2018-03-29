require "spec_helper"
require "chef-workstation/action/converge_target"
require "chef-workstation/status_reporter"
require "chef-workstation/remote_connection"

RSpec.describe ChefWorkstation::Action::ConvergeTarget do
  let(:reporter) { instance_double(ChefWorkstation::StatusReporter) }
  let(:connection) do
    p = double("platform", family: "windows")
    instance_double(ChefWorkstation::RemoteConnection, platform: p)
  end
  let(:r1) { "directory" }
  let(:r2) { "/tmp" }
  let(:attrs) { nil }
  let(:opts) { { reporter: reporter, connection: connection, resource_type: r1, resource_name: r2, attributes: attrs } }
  subject(:action) { ChefWorkstation::Action::ConvergeTarget.new(opts) }

  describe "#initialize" do
    it "properly initializes exposed attribute readers" do
      expect(action.resource_type).to eq r1
      expect(action.resource_name).to eq r2
    end
  end

  describe "#perform_action" do
    let(:result) { double("command result", exit_status: 0, stdout: "") }

    it "runs the converge and reports back success" do
      expect(connection).to receive(:run_command).with(/chef-apply.+#{r1}/).and_return(result)
      expect(reporter).to receive(:success).with(/#{r1}/)
      action.perform_action
    end

    context "when attributes are provided" do
      let(:attrs) do
        {
          "key1" => "value",
          "key2" => 0.1,
          "key3" => 100,
          "key4" => true,
          "key_with_underscore" => "value",
        }
      end
      it "runs the converge and reports back success" do
        expect(connection).to receive(:run_command).with(
          "cmd /c C:/opscode/chef/bin/chef-apply --no-color -e \"directory '/tmp' do; " \
          "key1 \\\"value\\\"; " \
          "key2 0.1; " \
          "key3 100; " \
          "key4 true; " \
          "key_with_underscore \\\"value\\\"; " \
          "end\""
        ).and_return(result)
        expect(reporter).to receive(:success).with(/#{r1}/)
        action.perform_action
      end
    end

    context "when command fails" do
      before do
        expect(connection).to receive(:run_command).with(/chef-apply.+#{r1}/).and_return(result)
      end
      let(:result) { double("command result", exit_status: 1) }
      let(:stacktrace_result) { double("stacktrace scrape result", exit_status: 0, stdout: "") }

      it "scrapes the remote log" do
        expect(reporter).to receive(:error).with(/converge/)
        expect(connection).to receive(:run_command).with(/chef-stacktrace/).and_return(stacktrace_result)
        action.perform_action
      end

      context "when remote log cannot be retrieved" do
        let(:stacktrace_result) { double("stacktrace scrape result", exit_status: 1, stdout: "", stderr: "") }
        it "logs results from the attempt" do
          expect(reporter).to receive(:error).with(/converge/)
          expect(connection).to receive(:run_command).with(/chef-stacktrace/).and_return(stacktrace_result)
          action.perform_action
        end
      end
    end
  end

end
