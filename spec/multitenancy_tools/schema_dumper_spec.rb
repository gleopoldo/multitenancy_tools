require 'spec_helper'
require 'support/db'
require 'tempfile'

RSpec.describe MultitenancyTools::SchemaDumper do
  before(:all) do
    Db.setup
    Db.connect

    Db.connection.create_schema('schema1')
    Db.connection.schema_search_path = 'schema1'

    silence_stream(STDOUT) do
      ActiveRecord::Schema.define(version: 20140407140000) do
        create_table 'posts', force: true do |t|
          t.text 'title'
          t.text 'body'
        end
      end
    end
  end

  after(:all) do
    Db.teardown
  end

  describe '#dump_to' do
    let(:io) { StringIO.new }

    subject do
      described_class.new(Db.name, 'schema1')
    end

    context 'schema exists' do
      before do
        subject.dump_to(io)
        io.rewind
      end

      it 'generates a SQL dump of the schema' do
        expect(io.read).to eql(File.read('spec/fixtures/schema_dump.sql'))
      end

      it 'contains create table statements' do
        expect(io.read).to match(/CREATE TABLE posts/)
      end

      it 'does not include table data' do
        expect(io.read).to_not match(/COPY posts/)
      end

      it 'does not dump privileges' do
        expect(io.read).to_not match(/GRANT|REVOKE/)
      end

      it 'does not dump tablespace assignments' do
        expect(io.read).to_not match(/default_tablespace/)
      end

      it 'does not include object ownership' do
        expect(io.read).to_not match(/OWNER TO/)
      end

      it 'does not include create schema statements' do
        expect(io.read).to_not match(/CREATE SCHEMA/)
      end

      it 'does not set search_path' do
        expect(io.read).to_not match(/SET search_path/)
      end

      it 'does not include any comments' do
        expect(io.read).to_not match(/--/)
      end

      it 'removes duplicate line breaks' do
        expect(io.read).to_not match(/\n\n/)
      end
    end

    context 'schema does not exist' do
      subject do
        described_class.new(Db.name, 'schema2')
      end

      it 'raises an error' do
        expect do
          subject.dump_to(io)
        end.to raise_error(MultitenancyTools::PgDumpError,
                           /No matching schemas were found/)
      end
    end
  end
end
