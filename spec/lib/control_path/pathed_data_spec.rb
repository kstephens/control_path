require 'spec_helper'
require 'control_path/pathed_data'

module ControlPath
  describe PathedData do
    Error = PathedData::Error
    subject { PathedData[data] }
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

    describe "#[]" do
      it "returns elems" do
        expect(subject[''])     .to eq data
        expect(subject['a'])    .to eq data[:a]
        expect(subject['c/d'])  .to eq data[:c][:d]
        expect(subject['unknown']) .to eq nil
        expect{subject['a/b']}  .to raise_error(Error::InvalidPath, 'a/b')
      end
    end

    context "#[]=" do
      let(:v) { rand }
      it "''" do
        subject[''] = v
        expect(subject.data)  .to eq v
        expect(subject.modified?) .to be_falsey
      end
      it "'a'" do
        subject['a'] = v
        expect(subject.data)  .to eq data.merge(a: v)
        expect(subject.modified?) .to be_truthy
        expect(subject.modified?(data[:c])) .to be_falsey
      end
      it "'c/d'" do
        subject['c/d'] = v
        expect(subject.data)  .to eq data.merge(c: { d: v, e: 4 })
        expect(subject.modified?) .to be_falsey
        expect(subject.modified?(data[:c])) .to be_truthy
      end
      it "'c'" do
        subject['c'] = v
        expect(subject.data)  .to eq data.merge(c: v)
        expect(subject.modified?) .to be_truthy
        expect(subject.modified?(data[:c])) .to be_falsey
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
