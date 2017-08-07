require 'nokogiri'

module Goods
  class XML
    class InvalidFormatError < StandardError; end

    def initialize(string_or_io, url = nil, encoding = nil)
      @xml_source = Nokogiri::XML::Document.parse(string_or_io, url, encoding)
    end

    def categories
      @categories ||= Util::CategoriesGraph.new(extract_categories).topsorted
    end

    def currencies
      @currencies ||= extract_currencies
    end

    def delivery_options
      @delivery_options ||= extract_delivery_options
    end

    def offers
      @offers ||= extract_offers
    end

    def generation_date
      @generation_date ||= extract_catalog_generation_date
    end

    def name
      @name ||= extract_text shop_node, 'name'
    end

    def company
      @company ||= extract_text shop_node, 'company'
    end

    def url
      @url ||= extract_text shop_node, 'url'
    end

    private

    def catalog_node
      @xml_source / 'yml_catalog'
    end

    def shop_node
      res = catalog_node / 'shop'
      res.empty? ? catalog_node / 'vendor' : res
    end

    def extract_catalog_generation_date
      Time.zone.parse(catalog_node.attribute('date').value) rescue nil
    end

    #---------------------------------------------------------------------------
    # Categories part
    #---------------------------------------------------------------------------

    def categories_node
      shop_node / 'categories' / 'category'
    end

    def extract_categories
      categories_node.map { |v| category_node_to_hash(v) }
    end

    def category_node_to_hash(category)
      parent_id = extract_attribute(category, 'parentId')
      {
        id: extract_attribute(category, :id),
        name: extract_text(category),
        parent_id: parent_id == '0' ? nil: parent_id
      }
    end

    #---------------------------------------------------------------------------
    # Currencies part
    #---------------------------------------------------------------------------

    def currencies_node
      shop_node / 'currencies' / 'currency'
    end

    def extract_currencies
      currencies_node.map { |v| currency_node_to_hash(v) }
    end

    def currency_node_to_hash(currency)
      currency_hash = { id: extract_attribute(currency, 'id') }
      attributes_with_defaults = { rate: '1', plus: '0' }

      attributes_with_defaults.each do |attr, default|
        currency_hash[attr] = extract_attribute(currency, attr, default)
      end

      currency_hash
    end

    #---------------------------------------------------------------------------
    # Delivery options part
    #---------------------------------------------------------------------------

    def extract_delivery_options
      delivery_options_node.map do |v|
        ::Goods::DeliveryOption.new(delivery_option_node_to_hash(v))
      end
    end

    def delivery_options_node
      shop_node > 'delivery-options' > 'option'
    end

    def delivery_option_node_to_hash delivery_option
      {
        cost: extract_attribute(delivery_option, :cost),
        days: extract_attribute(delivery_option, :days),
        order_before: extract_attribute(delivery_option, 'order-before')
      }
    end

    #---------------------------------------------------------------------------
    # Offers part
    #---------------------------------------------------------------------------

    def offer_nodes
      res = shop_node / 'offers' / 'offer'
      res.empty? ? (shop_node / 'models' / 'model') : res
    end

    def offer_barcode_nodes offer_node
      offer_node / 'barcode'
    end

    def offer_param_nodes offer_node
      offer_node / 'param'
    end

    def offer_age_node offer_node
      (offer_node / 'age').first
    end

    def offer_picture_nodes offer_node
      res = offer_node / 'picture'
      res.empty? ? offer_node / 'pictureUrl' : res
    end

    def extract_offers
      offer_nodes.map do |v|
        offer = ::Goods::Offer.new(offer_node_to_hash(v))
        offer.age = offer_age(v)
        offer.barcodes = offer_barcodes(v)
        offer.params = offer_params(v)
        offer.pictures = offer_pictures(v)
        offer
      end
    end

    def offer_node_to_hash(offer_node)
      offer_hash = {}

      # offer attributes
      offer_hash = offer_hash.merge(
        id: extract_attribute(offer_node, 'id'),
        group_id: extract_attribute(offer_node, 'group_id'),
        type: extract_attribute(offer_node, 'type'),
        available: (extract_attribute(offer_node, 'available', 'true') == 'true')
      )

      # nested elements
      {
        url: 'url',
        currency_id: 'currencyId',
        category_id: 'categoryId',
        picture: 'picture',
        pickup: 'pickup',
        delivery: 'delivery',
        type_prefix: 'typePrefix',
        vendor: 'vendor',
        vendor_code: 'vendorCode',
        model: 'model',
        name: 'name',
        isbn: 'ISBN',
        description: 'description',
        sales_notes: 'sales_notes',
        adult: 'adult'
      }.each do |element, xpath|
        offer_hash[element] = extract_text(offer_node, xpath)
      end

      offer_hash[:price] = extract_text(offer_node, 'price')&.tr(',', '')&.to_f
      offer_hash[:oldprice] = extract_text(offer_node, 'oldprice')&.tr(',', '')&.to_f

      offer_hash
    end

    def offer_age offer_node
      age_node = offer_age_node(offer_node)
      return if age_node.nil?

      ::Goods::Age.new offer_age_node_to_hash(age_node)
    end

    def offer_age_node_to_hash offer_age_node
      {
        unit: extract_attribute(offer_age_node, 'unit'),
        value: extract_text(offer_age_node)
      }
    end

    def offer_barcodes offer_node
      offer_barcode_nodes(offer_node).map { |v| extract_text(v) }
    end

    def offer_params offer_node
      offer_param_nodes(offer_node).map do |v|
        ::Goods::Param.new(offer_param_node_to_hash(v))
      end
    end

    def offer_pictures offer_node
      offer_picture_nodes(offer_node).map do |v|
        ::Goods::Picture.new(offer_picture_node_to_hash(v))
      end
    end

    def offer_param_node_to_hash offer_param_node
      {
        name: extract_attribute(offer_param_node, 'name'),
        unit: extract_attribute(offer_param_node, 'unit'),
        value: extract_text(offer_param_node)
      }
    end

    def offer_picture_node_to_hash offer_picture_node
      {
          url: extract_text(offer_picture_node)
      }
    end

    def extract_attribute(node, attribute, default = nil)
      if node.attribute(attribute.to_s)
        node.attribute(attribute.to_s).value.strip
      else
        default
      end
    end

    def extract_text(node, xpath = nil, default = nil)
      target = if xpath
        node.search(xpath).first
      else
        node
      end

      if target
        target.text.strip
      else
        default
      end
    end
  end
end
