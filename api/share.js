export default async function handler(req, res) {
  const { id } = req.query;

  const APP_URL = 'https://agridirect-app.vercel.app';

  if (!id) {
    res.redirect(302, `${APP_URL}/marketplace`);
    return;
  }

  const supabaseUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/products?product_id=eq.${id}&select=*`, {
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`
      }
    });

    const products = await response.json();
    const product = products && products.length > 0 ? products[0] : null;

    if (!product) {
       res.redirect(302, `${APP_URL}/product-details?id=${id}`);
       return;
    }

    const title = product.name ? `${product.name} - AgriDirect` : 'AgriDirect Product';
    const description = product.description 
        ? (product.description.length > 100 ? product.description.substring(0, 97) + '...' : product.description)
        : `Fresh farm product available now for ₱${product.price || '0.00'}.`;
    const image = product.image_url || 'https://agridirect-app.vercel.app/icons/Icon-512.png';
    const redirectUrl = `${APP_URL}/product-details?id=${id}`;

    const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>${title}</title>
          
          <!-- Open Graph / Facebook -->
          <meta property="og:type" content="website">
          <meta property="og:url" content="${redirectUrl}">
          <meta property="og:title" content="${title}">
          <meta property="og:description" content="${description}">
          <meta property="og:image" content="${image}">

          <!-- Twitter -->
          <meta property="twitter:card" content="summary_large_image">
          <meta property="twitter:url" content="${redirectUrl}">
          <meta property="twitter:title" content="${title}">
          <meta property="twitter:description" content="${description}">
          <meta property="twitter:image" content="${image}">
          
          <script>
             window.location.replace("${redirectUrl}");
          </script>
      </head>
      <body>
          <p>Redirecting to ${title}...</p>
      </body>
      </html>
    `;
    
    res.setHeader('Content-Type', 'text/html');
    res.status(200).send(html);

  } catch (err) {
    res.redirect(302, `${APP_URL}/product-details?id=${id}`);
  }
}
