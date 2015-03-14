require 'spec_helper'

describe Kamome do
  let(:model) { User }

  it 'has a version number' do
    expect(Kamome::VERSION).not_to be nil
  end

  it "is kamome" do
    expect(model.kamome_enable?).to be true
  end

  context "switch target" do
    before do
      Kamome.target = :blue
      User.create!(name: 'blue')
      Kamome.target = :green
      User.create!(name: 'green')
    end

    describe "=blue" do
      before { Kamome.target = :blue }

      it "blue database exist user record" do
        expect(model.where(name: 'blue').exists?).to be true
      end

      it "blue database empty green user record" do
        expect(model.where(name: 'green').exists?).to be false
      end
    end

    describe "=green" do
      before { Kamome.target = :green }

      it "green database exist user record" do
        expect(model.where(name: 'green').exists?).to be true
      end

      it "green database empty blue user record" do
        expect(model.where(name: 'blue').exists?).to be false
      end
    end
  end

  context "block targetting" do
    before do
      Kamome.target = :blue
      User.create!(name: 'blue')
      Kamome.anchor(:green) do
        User.create!(name: 'green')
      end
      User.create!(name: 'blue')
    end

    describe "=blue" do
      before { Kamome.target = :blue }

      it "confirm record count" do
        expect(model.where(name: 'blue').count).to be 2
        expect(model.where(name: 'green').count).to be 0
      end
    end

    describe "=green" do
      before { Kamome.target = :green }

      it "confirm record count" do
        expect(model.where(name: 'green').count).to be 1
        expect(model.where(name: 'blue').count).to be 0
      end
    end
  end

  context "multiple transaction" do
    describe "only blue transaction" do
      before do
        Kamome.target = :blue
        begin
          User.transaction do
            Kamome.anchor(:green) do
              User.create!(name: 'green')
            end
            User.create!(name: 'blue')
            User.create!
          end
        rescue ActiveRecord::RecordInvalid
        end
      end

      describe "confirm record count" do
        it "=blue" do
          Kamome.anchor(:blue)  { expect(model.count).to be 0 }
        end

        it "=green" do
          Kamome.anchor(:green) { expect(model.count).to be 1 }
        end
      end
    end

    describe "Kamome.transaction" do
      before do
        Kamome.target = :blue
        begin
          Kamome.transaction(:blue, :green) do
            Kamome.anchor(:green) do
              User.create!(name: 'green')
            end
            User.create!(name: 'blue')
            User.create!
          end
        rescue ActiveRecord::RecordInvalid
        end
      end

      describe "confirm record count" do
        it "=blue" do
          Kamome.anchor(:blue)  { expect(model.count).to be 0 }
        end

        it "=green" do
          Kamome.anchor(:green) { expect(model.count).to be 0 }
        end
      end
    end

    describe "Kamome.full_transaction" do
      before do
        Kamome.target = :blue
        begin
          Kamome.full_transaction do
            Kamome.anchor(:green) do
              User.create!(name: 'green')
            end
            User.create!(name: 'blue')
            User.create!
          end
        rescue ActiveRecord::RecordInvalid
        end
      end

      describe "confirm record count" do
        it "=blue" do
          Kamome.anchor(:blue)  { expect(model.count).to be 0 }
        end

        it "=green" do
          Kamome.anchor(:green) { expect(model.count).to be 0 }
        end
      end
    end
  end
end
