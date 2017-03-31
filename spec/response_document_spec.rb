require 'spec_helper'

describe 'Resource document structure', type: :request do
  let!(:comments) { create_list :comment, 1 }

  describe 'non-JSON url' do
    before { get "/api/v1/static" }

    it 'responds' do
      expect(response.status).to eq(200)
    end

    it 'does not force a JSON resource document' do
      expect { json }.to raise_error(JSON::ParserError)
    end
  end

  describe 'type' do
    before { get "/api/v1/#{resource.class.name.underscore.pluralize}/#{resource.id}" }

    subject(:resource) { comments.first }

    it 'uses the resource model name' do
      expect(json['data']['type']).to eq('comments')
    end

    context 'when resource is serialized by parent resource model serializer' do
      subject(:resource) { create :post, :with_attachments }

      it 'uses the parent resource model name' do
        expect(json['data']['relationships']['attachments']['data'][0]['type']).to eq('attachments')
      end
    end
  end

  describe 'meta' do
    before do
      API::V1::CommentsController.send :define_method, :add_meta_tag do
        meta[:tag_1] = 100
        meta[:tag_2] = 'tagged'
      end
      API::V1::CommentsController.before_query(:add_meta_tag)
    end

    after do
      API::V1::CommentsController.instance_variable_set('@before_query_callbacks', [])
    end

    before { get '/api/v1/comments/' }

    it 'adds meta tags to the response document' do
      expect(json['meta']['tag_1']).to eq(100)
      expect(json['meta']['tag_2']).to eq('tagged')
    end
  end

  describe 'links' do
    include Rails.application.routes.url_helpers

    before { Rails.application.routes.default_url_options[:host] = 'http://www.example.com' }

    before { get "/api/v1/#{resource_path}/#{resource.id}" }

    subject(:resource) { comments.first }
    let(:resource_path) { resource.class.name.underscore.pluralize }

    it 'includes self link' do
      expect(json['data']['links']['self']).to eq(api_v1_comment_url(resource))
    end

    # TODO: Implement and spec only_path option

    context 'when resource is serialized by parent resource model serializer' do
      subject(:resource) { create :image }
      let(:resource_path) { 'attachments' }

      it 'uses the parent resource model link' do
        expect(json['data']['links']['self']).to eq(api_v1_attachment_url(resource))
      end
    end
  end

  describe 'relationships' do
    context 'when scoping relationships' do
      let(:post) { create :post }
      let!(:comments)       { create_list :comment, 2, post: post, user: post.user }
      let!(:other_comments) { create_list :comment, 1, post: post, user: create(:user) }

      before do
        API::V1::PostSerializer.instance_eval do
          define_method :relationship_scope do |name, scope|
            case name
            when :comments
              scope.where(user: object.user)
            else
              scope
            end
          end
        end
      end

      after do
        API::V1::PostSerializer.instance_eval do
          remove_method :relationship_scope
        end
      end

      before { get "/api/v1/posts/#{post.id}?include=comments" }

      it 'only includes scoped relationship items' do
        expect(json['included'].count).to eq(2)
      end
    end

    context 'when optimizing relationships' do
      before { Caprese.config.optimize_relationships = true }
      after { Caprese.config.optimize_relationships = false }

      before { get "/api/v1/comments/#{comments.first.id}#{query_str}" }

      context 'when association included' do
        subject(:query_str) { '?include=post' }

        it 'serializes the relationship data' do
          expect(json['data']['relationships']['post']['data']).not_to be_nil
        end
      end

      context 'when association not included' do
        subject(:query_str) { '' }

        it 'does not serialize the relationship data' do
          expect(json['data']['relationships']['post']['data']).to be_nil
        end
      end

      context 'when deep nesting' do
        subject(:post_params) { json['included'].detect { |r| r['type'] == 'posts' } }

        context 'when association included' do
          subject(:query_str) { '?include=post.user' }

          it 'serializes the relationship data' do
            expect(post_params['relationships']['user']['data']).not_to be_nil
          end
        end

        context 'when association not included' do
          subject(:query_str) { '?include=post' }

          it 'does not serialize the relationship data' do
            expect(json['data']['relationships']['user']['data']).to be_nil
          end
        end
      end
    end
  end

  describe 'attribute aliasing' do
    before do
      Comment.instance_eval do
        define_method :caprese_is_attribute? do |name|
          %w(not_attribute).include?(name.to_s)
        end
      end

      API::V1::CommentsController.send :define_method, :add_error do |resource|
        resource.errors.add(:not_attribute, :blank)
      end
      API::V1::CommentsController.before_create(:add_error)
    end

    after do
      API::V1::CommentsController.instance_variable_set('@before_create_callbacks', [])

      Comment.instance_eval do
        remove_method :caprese_is_attribute?
      end
    end

    before { post '/api/v1/comments', { data: { type: 'comments' } } }

    it 'indicates that the alias is an attribute' do
      expect(json['errors'][0]['source']['pointer']).to eq('/data/attributes/not_attribute')
    end
  end
end
