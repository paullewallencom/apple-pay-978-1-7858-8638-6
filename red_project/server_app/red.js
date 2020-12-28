/* red.js
 */
 
var models=    require('./lib/inventory_models.js');
var assert=    require('assert');
var mongoose=  require('mongoose');
var restify=   require('restify');
var stripe=    require('stripe')('sk_test_wYf2iUHNrA68GicYq3Vmgm2m')
//var RNCryptor= require('jscryptor');

//var fs=       require('fs');
//var server=   restify.createServer(
//{
//   certificate:        fs.readFileSync('../certificates/cert.pem'),
//   key:                fs.readFileSync('../certificates/key2.pem'),
//   requestCert:        true,
//   rejectUnauthorized: true
//});

var server=   restify.createServer();
server.use(restify.bodyParser());

Product=         models.Product;
ShippingMethod=  models.ShippingMethod;
Order=           models.Order;
mongoose.connect('mongodb://localhost/red');

protocol='http://';
hostname= 'red';
port= 12345;
base_uri= protocol + hostname + ':' + port;
console.log(base_uri);


Product.find(function(error, _products)
{
   //console.log(_products);
   if (_products.length == 0)
   {
      console.log('initializing product collection');
      models.Product(
      {
         name:             'Clock', 
         description:      'Wooden clock', 
         quantity_on_hand: 10,
         price:            '50.00',
         image_uri:        base_uri + '/product_image/clock.jpeg'
      }).save();
      models.Product(
      {
         name:             'Pen',
         description:      'Metal pen',
         quantity_on_hand: 50,
         price:            '25.00',
         image_uri:        base_uri + '/product_image/pen.jpeg'
      }).save();
      models.Product(
      {
         name:             'Pencil',
         description:      '#2 pencil',
         quantity_on_hand: 50,
         price:            '0.50',
         image_uri:        base_uri + '/product_image/pencil.jpeg'
      }).save();
      models.Product(
      {
         name:             'Stapler',
         description:      'Orange stapler',
         quantity_on_hand: 50,
         price:            '15.00',
         image_uri:        base_uri + '/product_image/stapler5.jpeg'
      }).save();
      models.Product(
      {
         name:             'Cup',
         description:      'Ceramic cup (without coffee)',
         quantity_on_hand: 50,
         price:            '20.00',
         image_uri:        base_uri + '/product_image/cup.jpeg'
      }).save();
      models.Product(
      {
         name:             'Catpad',
         description:      'Catpad with gray cat',
         quantity_on_hand: 50,
         price:            '12.00',
         image_uri:        base_uri + '/product_image/catpad2.jpeg'
      }).save();
      models.Product(
      {
         name:             'Chocolate Hearts',
         description:      'Delicious chocolate wrapped in red',
         quantity_on_hand: 50,
         price:            '8.00',
         image_uri:        base_uri + '/product_image/chocolate3.jpeg'
      }).save();
      models.Product(
      {
         name:             'White Eraser',
         description:      'Eraser with “Delete” label (like the button)',
         quantity_on_hand: 50,
         price:            '8.00',
         image_uri:        base_uri + '/product_image/eraser.jpeg'
      }).save();
      models.Product(
      {
         name:             'Hammer',
         description:      'Hammer to nail down things',
         quantity_on_hand: 50,
         price:            '7.00',
         image_uri:        base_uri + '/product_image/hammer.jpeg'
      }).save();
      models.Product(
      {
         name:             'Red Scarf',
         description:      'Stylish scarf',
         quantity_on_hand: 50,
         price:            '8.00',
         image_uri:        base_uri + '/product_image/scarf2.jpeg'
      }).save();
      models.Product(
      {
         name:             'T-Ruller',
         description:      'Get things straight',
         quantity_on_hand: 50,
         price:            '14.00',
         image_uri:        base_uri + '/product_image/t-ruler.jpeg'
      }).save();
      models.Product(
      {
         name:             'Whiteboard Eraser',
         description:      'Wipe the slate clean',
         quantity_on_hand: 50,
         price:            '5.00',
         image_uri:        base_uri + '/product_image/whiteboard_eraser.jpeg'
      }).save();
   }
});

var products= new Array();
Product.find(function(error, _products)
{
   products= _products;
});


// shipping methods
ShippingMethod.find(function(error, _shipping_methods)
{
   if (_shipping_methods.length == 0)
   {
      console.log('initializing shipping-method collection');
      models.ShippingMethod({
         name:         'Free',
         description:  'Delivers in seven days',
         transit_days: 7,
         price:        '0.00'
      }).save();
      models.ShippingMethod({
         name:         'Standard',
         description:  'Delivers in four days',
         transit_days: 4,
         price:        '5.00'
      }).save();
      models.ShippingMethod({
         name:         'Expedited',
         description:  'Delivers tomorrow',
         transit_days: 1,
         price:        '15.00'
      }).save();
   }
})

var shipping_methods= new Array();
ShippingMethod.find(function(error, _shipping_methods)
{
   shipping_methods= _shipping_methods;
});


function sendV1(request, response, next)
{
   response.send('hello: ' + request.params.name);
   return next();
}

function sendV2(request, response, next)
{
   response.send({hello: request.params.name});
   return next();
}

//var PATH= '/hello/:name';
//server.get({path: PATH, version: '1.1.3'}, sendV1);
//server.get({path: PATH, version: '2.0.0'}, sendV2);

// serve static content
server.get(/\/product_image\/?.*/, restify.serveStatic( { directory: '../public' }));


// inventory api
server.get('/inventory', function(request, response, next)
{
   //console.log('AGENT'   + JSON.stringify(request.agent));
   //console.log('METHOD'  + JSON.stringify(request.method));
   //console.log('HEADERS' + JSON.stringify(request.headers));
   //console.log(products);
   response.send(products);
   next();
});
server.get('/shipping_methods', function(request, response, next)
{
   //console.log(shipping_methods);
   response.send(shipping_methods);
   next();
});


// payment api
server.post('/payment', function(request, response, next)
{
   // parse request
   var order_info_package= JSON.parse(request.body);
   
   // process charge token
   if (order_info_package.gateway == 'stripe')
   {
      // 2. charge payment card
      var charge= stripe.charges.create
      (
         {
            amount      : order_info_package.amount,
            currency    : order_info_package.currency,
            source      : order_info_package.source,
            description : 'charge for ' + order_info_package.description
         }, 
         function(error, charge)
         {
            var transaction_info= 
            {
               id     : charge.id,
               status : charge.status
            }
            
            if (error)
               console.log('there’s an error creating a charge: ' + error);
            else
            {
               // 3.a update inventory
               // ...
               
               // 3.b create order
               var order= models.Order(
               {
                  date                 : new Date(),
                  description          : order_info_package.description,
                  shipping_email       : order_info_package.shipping_email,
                  shipping_street      : order_info_package.shipping_street,
                  shipping_city        : order_info_package.shipping_city,
                  shipping_state       : order_info_package.shipping_state,
                  shipping_zip         : order_info_package.shipping_zip,
                  shipping_method_name : order_info_package.shipping_method_name,
                  total_price          : order_info_package.amount,
                  stripe_charge_id     : charge.id
               });
               order.save();
               
               transaction_info.order_id= order._id;
            }
            
            // 4. send transaction result to customer’s device 
            response.send(transaction_info);
         }
      );
   }
   next();
});

/*
var password = 'myPassword';
var b64string = "AwHsr+ZD87myaoHm51kZX96u4hhaTuLkEsHwpCRpDywMO1Moz35wdS6OuDgq+SIAK6BOSVKQFSbX/GiFSKhWNy1q94JidKc8hs581JwVJBrEEoxDaMwYE+a+sZeirThbfpup9WZQgp3XuZsGuZPGvy6CvHWt08vsxFAn9tiHW9EFVtdSK7kAGzpnx53OUSt451Jpy6lXl1TKek8m64RT4XPr";

var RNCryptor = require('jscryptor');

console.time('Decrypting example');
var decrypted = RNCryptor.Decrypt(b64string, password);
console.timeEnd('Decrypting example');
console.log("Result:", decrypted);
*/

server.listen(12345);
