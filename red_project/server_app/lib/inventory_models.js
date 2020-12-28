/* inventory_schema.js
 */
 
var mongoose= require('mongoose');
var Schema=   mongoose.Schema;

var Product_schema= new Schema({
   name:             String,
   description:      String,
   image_uri:        String,
   quantity_on_hand: Number,
   price:            String
});

var ShippingMethod_schema= new Schema({
   name:         String,
   description:  String,
   transit_days: Number,
   price:        String
});

var Order_schema= new Schema({
   date                 : String,
   description          : String,
   shipping_contact     : String,
   shipping_email       : String,
   shipping_street      : String,
   shipping_city        : String,
   shipping_state       : String,
   shipping_zip         : String,
   shipping_method_name : String,
   total_price          : String,
   stripe_charge_id     : String
});
   
exports.Product=        mongoose.model('Product',         Product_schema);
exports.ShippingMethod= mongoose.model('ShippingMethod',  ShippingMethod_schema);
exports.Order=          mongoose.model('Order',           Order_schema);