module Goods
  class Offer < Element
    attr_accessor :age, :category, :currency, :price, :params, :barcodes, :pictures

    attr_field :url
    attr_field :price, type: :float
    # NOTE: don't specify float type so that nil is not cast to 0
    attr_field :oldprice
    attr_field :currency_id
    attr_field :category_id
    attr_field :categoryId
    attr_field :picture
    attr_field :pickup
    attr_field :delivery

    # fields that depend on specific feed type
    attr_field :type_prefix
    attr_field :vendor
    attr_field :vendor_code
    attr_field :model
    attr_field :name
    attr_field :isbn
    attr_field :description
    attr_field :sales_notes
    attr_field :adult

    # offer attributes
    attr_field :group_id
    attr_field :type
    attr_field :available

    def convert_currency(another_currency)
      self.price *= currency.in(another_currency)
      self.currency = another_currency
      @currency_id = another_currency.id
    end

    def change_category(another_category)
      self.category = another_category
      @category_id = another_category.id
    end

    def price=(price)
      @price = price
    end

    private

    def apply_validation_rules
      validate :id, proc { |val| val.present? }
      validate :category_id, proc { |category_id| category_id.present? }
      validate :currency_id, proc { |currency_id| currency_id.present? }
      validate :price, proc { |price| price.present? && price >= 0 }
    end
  end
end
