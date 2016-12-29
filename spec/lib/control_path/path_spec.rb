require 'spec_helper'
require 'control_path/path'

module ControlPath
  describe Path do
    subject { Path[rep] }
    let(:rep) { "a/0/c" }

    describe "[]" do
      it "has elements" do
        expect(subject.elements) .to eq [:a, 0, :c]
      end
      it "is fixed point" do
        expect(Path[subject].object_id) .to eq subject.object_id
      end
    end

    describe ".[]" do
      it "returns a normalized Path" do
        expect(Path[''].to_a)      .to eq [ ]
        expect(Path['.'].to_a)     .to eq [ ]
        expect(Path['//'].to_a)    .to eq [ :'', :'' ]
        expect(Path['a'].to_a)     .to eq [ :a ]
        expect(Path['a/b'].to_a)   .to eq [ :a, :b ]
        expect(Path['/a/b'].to_a)  .to eq [ :'', :a, :b ]
        expect(Path['a//b///c'].to_a) .to eq [ :a, :b, :c ]
        expect(Path['//a//b///c'].to_a) .to eq [ :'', :a, :b, :c ]
        expect(Path['//a//b///c/'].to_a) .to eq [ :'', :a, :b, :c, :'' ]
      end
    end

    describe "#/" do
      it "concats elements" do
        expect((subject / nil).to_a)   .to eq [:a, 0, :c]
        expect((subject / []).to_a)    .to eq [:a, 0, :c]
        expect((subject / "x/y").to_a) .to eq [:a, 0, :c, :x, :y]
      end
    end

    describe "#absolute?" do
      it "works" do
        expect(Path[].absolute?)     .to be false
        expect(Path[nil].absolute?)  .to be false
        expect(Path["//"].absolute?) .to be true
        expect(Path["a"].absolute?)  .to be false
        expect(Path["/a"].absolute?)  .to be true
      end
    end

    describe "#deep?" do
      it "works" do
        expect(Path[].deep?)      .to be false
        expect(Path[nil].deep?)   .to be false
        expect(Path["//"].deep?)  .to be true
        expect(Path["a"].deep?)   .to be false
        expect(Path["/a"].deep?)    .to be false
        expect(Path["/a/"].deep?)   .to be true
        expect(Path["/a/b"].deep?)  .to be false
      end
    end

    describe "#empty?" do
      it "works" do
        expect(Path[].empty?)     .to be true
        expect(Path[nil].empty?)  .to be true
        expect(Path[""].empty?)   .to be true
        expect(Path["//"].empty?) .to be false
        expect(Path["a"].empty?)  .to be false
        expect(Path["a"].rest.empty?)  .to be true
      end
    end

    describe "misc" do
      it "acts like an Array" do
        expect(subject.size) .to eq 3
        expect(subject.empty?) .to eq false
        expect(subject.first) .to eq :a
      end
    end

    describe "#glob" do
      let(:root) do
        {
          a: 1,
          b: 2,
          c: {
            d: 3,
            e: 4,
            f: {
              x: 6,
              y: 7,
            }
          },
          f: 5,
          bar: 11,
        }
      end
      let(:glob) { lambda { |p| Path[p].glob(root).map(&:to_s) } }
      context "for ordinary Paths" do
        it "returns Paths" do
          expect(glob[''])  .to eq []
          expect(glob['a'])
            .to eq [ "a" ]
          expect(glob['a/c'])
            .to eq [ ]
          expect(glob['c'])
            .to eq [ "c" ]
        end
      end
      context "for * globs" do
        it "returns Paths" do
          expect(glob['*'])
            .to eq ["a", "b", "bar", "c", "f"]
          expect(glob['a/*'])
            .to eq [ ]
          expect(glob['c/*'])
            .to eq ["c/d", "c/e", "c/f"]
          expect(glob['*/*'])
            .to eq ["c/d", "c/e", "c/f"]
          expect(glob['*/*/*'])
            .to eq ["c/f/x", "c/f/y"]
          expect(glob['b*'])
            .to eq ["b", "bar"]
        end
      end
      context "for * globs" do
        it "returns Paths" do
          skip "not implemented"
          expect(glob['**'])
            .to eq [ "c/f/x", "c/f/y" ]
        end
      end
    end
  end
end
