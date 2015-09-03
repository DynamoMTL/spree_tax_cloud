module Solidus
  module CustomerReturnDecorator
    RMA = false

    def process_return!
      transaction = Spree::TaxCloudTransaction.transaction_with_taxcloud(order, RMA)
      iu_groups = inventory_units.group_by(&:variant_id)
      index = -1
      iu_groups.each do |key,value|
        quantity = value.count
        transaction.cart_items << Spree::TaxCloudTransaction.cart_item_from_return(Spree::LineItem.find(value.first.line_item_id), quantity, index += 1)
      end
      response = transaction.lookup
      if !response.blank?
        response_cart_items = response.cart_items
        tax_return_amount = 0.00
        response_cart_items.each do |cart_item|
          tax_return_amount += round_to_two_places( cart_item.tax_amount )
        end
        transaction.returned
        Adjustment.create(adjustable: order, amount: tax_return_amount.abs * -1, label: Spree.t(:rma_tax_credit), source: self)
        order.update!
      else
        raise ::SpreeTaxCloud::Error, 'TaxCloud response unsuccessful!'
      end

      super
    end

    def round_to_two_places(amount)
      BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
    end

  end
end

Spree::CustomerReturn.prepend ::Solidus::CustomerReturnDecorator
