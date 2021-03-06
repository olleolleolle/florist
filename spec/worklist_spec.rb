
#
# specifying florist
#
# Wed Feb 27 06:49:56 JST 2019
#

require 'spec_helper'


describe '::Florist::Worklist' do

  before :each do

    # use two databases
    # for testing

    @uri1 = storage_uri(:one, delete: true)
    @uri2 = storage_uri(:two, delete: true)

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: @uri1,
      sto_migration_table: :flor_schema_info)
    @unit.conf['unit'] = 'wlspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start

    Florist.delete_tables(@uri1)
    Florist.migrate(@uri1, table: :florist_schema_info)

    Florist.delete_tables(@uri2)
    Florist.migrate(@uri2, table: :florist_schema_info)

    @unit.add_tasker(
      'alice', Florist::WorklistTasker)
    @unit.add_tasker(
      'bob', class: Florist::WorklistTasker, db_uri: @uri2)

    @unit.launch(%q{ alice _ })
    @unit.launch(%q{ bob _ })

    db2 = Sequel.connect(@uri2)

    wait_until {
      @unit.storage.db[:florist_tasks].count == 1 &&
      db2[:florist_tasks].count == 1 }
  end

  after :each do

    @unit.shutdown
  end

  describe '.initialize' do

    describe '(db, conf)' do

      it 'instantiates a worklist' do

        l = Florist::Worklist.new(@unit.storage.db)

        expect(l.task_ds.count).to eq(1)
        expect(l.tasks.first.class.ancestors).to include(Sequel::Model)
      end
    end

    describe '(unit)' do

      it 'instantiates a worklist' do

        l = Florist::Worklist.new(@unit)

        expect(l.tasks.count).to eq(1)
        expect(l.tasks.first.class.ancestors).to include(Sequel::Model)
      end
    end

    describe '(flor_db, florist_db)' do

      it 'instantiates a worklist' do

        l = Florist::Worklist.new(@uri1, @uri2)

        expect(l.flor_db.uri).to eq(@uri1)
        expect(l.florist_db.uri).to eq(@uri2)
        expect(l.florist_db.uri).not_to eq(l.flor_db.uri)

        expect(l.tasks.count).to eq(1)
        expect(l.tasks.first.tasker).to eq('bob')
      end
    end

    describe '(no_florist_db)' do

      it 'fails' do

        expect {
          Florist::Worklist.new()
        }.to raise_error(
          ArgumentError, "missing a florist database"
        )
      end
    end

    describe 'domain: "org.acme"' do

      it 'instantiates a worklist limited to "org.acme.%"'# do

# TODO bring me back
#          l = Florist::Worklist.new(@unit, domain: 'org.acme')
#
#          expect(l.tasks.count).to eq(0)
#
#          @unit.launch(%q{ alice _ }, domain: 'org.acme.sub0')
#
#          wait_until { @unit.storage.db[:florist_tasks].count > 1 }
#
#          expect(l.tasks.count).to eq(1)
#          expect(l.tasks.first.domain).to eq('org.acme.sub0')
#        end
    end
  end
end

describe '::Florist::Worklist' do

  before :each do

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: storage_uri,
      sto_migration_table: :flor_schema_info)
    @unit.conf['unit'] = 'tskspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start

    @unit.add_tasker('alice', Florist::WorklistTasker)
    @unit.add_tasker('bob', Florist::WorklistTasker)

    Florist.delete_tables(storage_uri)
    Florist.migrate(storage_uri, table: :florist_schema_info)

    @worklist = Florist::Worklist.new(@unit)
  end

  after :each do

    @unit.shutdown
  end

  describe '#dump' do

    before :each do

      @unit.launch(%q{ alice _ }, domain: 'com.acme')
      @unit.launch(%q{ alice _ }, domain: 'acme.org.test')
      @unit.launch(%q{ bob _ }, domain: 'acme.org')

      wait_until { @unit.executions.count == 3 }
    end

    describe '()' do

      it 'dumps' do

        s = @worklist.dump

        h = JSON.load(s)

        expect(h.keys.sort).to eq(%w[
          assignments tasks timestamp transitions transitions_assignments ])
        expect(h['tasks'][0].keys.sort).to eq(%w[
          attls1 ctime data domain exid id mtime nid status tasker taskname ])
      end
    end
  end

  describe '#load' do

    describe '()' do

      it 'loads'
    end
  end
end

