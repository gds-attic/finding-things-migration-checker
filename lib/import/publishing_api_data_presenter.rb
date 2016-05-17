module Import
  module PublishingApiDataPresenter

    def self.present_content(content_id_data)
      # assumptions:
      # a content_id always has at least one content_item
      # each content_item of a given content_id has the same format and publishing_app

      exemplar = content_id_data['content_items'].first
      [content_id_data['content_id'], exemplar['publishing_app'], exemplar['format'], ever_published(content_id_data)]
    end

    def self.ever_published(content_id_data)
      published_state = content_id_data['content_items'].any? { |ci| ['published', 'unpublished', 'superseded'].include?(ci['state']) }
      published_state ? 'published_at_least_once' : 'never_published'
    end

    def self.present_links(content_id_data)

      links = parse_links(content_id_data)

      content_id = content_id_data['content_id']

      links.map { |link_arr| [content_id] + link_arr }
    end

    private

    def self.parse_links(content_id_data)
      content_id_data['links'].flat_map { |link_type| link_type[1].map { |link| [link_type[0], link] } }
    end

    def self.parse_base_paths(content_id_data)
      content_id_data['content_items'].map { |ci| ci["base_path"] }
    end
  end
end
