require 'spec_helper'
require 'control_path/service/store'
require 'fileutils'

module ControlPath::Service
  describe Store do
    subject do
      Store.new(logger: ::Logger.new($stderr),
                dir: dir)
    end
    let(:dir) { "tmp/test/data/#{$$}-#{Time.now.to_i}" }
    after do
      FileUtils.rm_rf(dir) rescue nil
    end

    describe "#path_parents" do
      it "returns list of parent paths" do
        expect { subject.path_parents(nil) } .to raise_error
        expect { subject.path_parents("") }  .to raise_error
        expect(subject.path_parents("/")) .to eq [ ]
        expect(subject.path_parents("/foo")) .to eq [ '/foo' ]
        expect(subject.path_parents("/foo/bar"))  .to eq [ '/foo/bar', '/foo' ]
      end
    end

    describe "#children" do
      before do
        subject.write!("/foo", "something.json", { data: '/foo' })
        subject.write!("/bar", "something.json", { data: '/bar' })
        subject.write!("/foo/bar", "something.json", { data: '/foo/bar' })
        subject.write!("/foo/baz", "something.json", { data: '/foo/baz' })
      end

      context "with deep /foo/ path" do
        it "returns list of child paths" do
          expect(subject.children("/", "something.json")) \
            .to eq [
                    {:file=>"#{dir}/bar/something.json",
                      :path=>"/bar",
                      :name=>"something.json"},
                    {:file=>"#{dir}/foo/something.json",
                      :path=>"/foo",
                      :name=>"something.json"},
                    {:file=>"#{dir}/foo/bar/something.json",
                      :path=>"/foo/bar",
                      :name=>"something.json"},
                    {:file=>"#{dir}/foo/baz/something.json",
                      :path=>"/foo/baz",
                      :name=>"something.json"},
                   ]
          expect(subject.children("/foo/", "something.json")) \
            .to eq [
                    {:file=>"#{dir}/foo/something.json",
                      :path=>"/foo",
                      :name=>"something.json"},
                    {:file=>"#{dir}/foo/bar/something.json",
                      :path=>"/foo/bar",
                      :name=>"something.json"},
                    {:file=>"#{dir}/foo/baz/something.json",
                      :path=>"/foo/baz",
                      :name=>"something.json"},
                   ]
        end
      end
      context "with shallow path" do
        it "returns list of child paths" do
          expect(subject.children("/bar", "something.json")) \
            .to eq [
                    {:file=>"#{dir}/bar/something.json",
                      :path=>"/bar",
                      :name=>"something.json"}
                   ]
          expect(subject.children("/foo", "something.json")) \
            .to eq [
                    {:file=>"#{dir}/foo/something.json",
                      :path=>"/foo",
                      :name=>"something.json"}
                   ]
        end
      end
    end

    describe "#parents" do
      it "returns list of parent paths" do
        subject.write!("/foo", "something.json", { data: '/foo' })
        subject.write!("/foo/bar", "something.json", { data: '/foo/bar' })
        subject.write!("/baz", "something.json", { data: '/baz' })
        expect(subject.parents("/", "something.json")) \
          .to eq []
        expect(subject.parents("/unknown", "something.json")) \
          .to eq []
        expect(subject.parents("/foo", "something.json")) \
          .to eq [{:file=>"#{dir}/foo/something.json",
                    :path=>"/foo",
                    :name=>"something.json"}]
        expect(subject.parents("/foo/bar", "something.json")) \
          .to eq [{:file=>"#{dir}/foo/bar/something.json",
                   :path=>"/foo/bar",
                   :name=>"something.json"},
                  {:file=>"#{dir}/foo/something.json",
                    :path=>"/foo",
                    :name=>"something.json"}]
        expect(subject.parents("/baz", "something.json")) \
          .to eq [{:file=>"#{dir}/baz/something.json",
                    :path=>"/baz",
                    :name=>"something.json"}]
      end
    end
  end
end
