require 'spec_helper'
require 'control_path/data_editor'
require 'fileutils'

module ControlPath
  describe DataEditor do
    Error = DataEditor::Error
    subject do
      DataEditor[data]
    end
    let(:data) do
      {
        a: 1,
        b: 2,
        c: {
          d: 3,
          e: 4,
        },
        f: 5,
      }
    end

    describe "#parse_path" do
      it "returns an Array of Symbols or Integers" do
        expect(subject.parse_path(''))   .to eq [ ]
        expect(subject.parse_path('.'))  .to eq [ ]
        expect(subject.parse_path('//')) .to eq [ ]
        expect(subject.parse_path('a/b')) .to eq [ :a, :b ]
      end
    end

    describe "#[]" do
      it "returns elems" do
        expect(subject[''])     .to eq data
        expect(subject['a'])    .to eq data[:a]
        expect{subject['a/b']}  .to raise_error(Error::InvalidPath, 'a/b')
        expect(subject['c'])    .to eq data[:c]
        expect(subject['asdf']) .to eq nil
      end
    end

    context "#[]=" do
      let(:v) { rand }
      it "''" do
        subject[''] = v
        expect(subject.data)  .to eq v
      end
      it "'a'" do
        subject['a'] = v
        expect(subject.data)  .to eq data.merge(a: v)
      end
      it "'c/d'" do
        subject['c/d'] = v
        expect(subject.data)  .to eq data.merge(c: { d: v, e: 4 })
      end
      it "'c'" do
        subject['c'] = v
        expect(subject.data)  .to eq data.merge(c: v)
      end
      it "'x/y'" do
        subject['x/y'] = v
        expect(subject.data)  .to eq data.merge(x: { y: v })
        expect(subject.modified?) .to be_truthy
        expect(subject.modified?(data[:x])) .to be_truthy
        expect(subject.modified?(data[:c])) .to be_falsey
      end
      it "'a' unmodified" do
        subject['a'] = data[:a]
        expect(subject.data)  .to eq data
        expect(subject.modified?) .to be_falsey
      end
    end
  end
end
