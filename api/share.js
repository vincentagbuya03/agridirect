export default async function handler(req, res) {
  const { id } = req.query;

  const APP_URL = 'https://agridirect-app.vercel.app';
  const DEFAULT_IMAGE = `${APP_URL}/icons/Icon-512.png`;
  const DEFAULT_TITLE = 'AgriDirect - Farm Direct E-commerce';
  const DEFAULT_DESC = 'Buy fresh, affordable, and high-quality produce directly from farmers on AgriDirect!';

  // Helper: always serve HTML (never 302) so Facebook reads OG tags properly.
  // Bots (Facebook, Twitter, etc.) execute no JS, so they see the OG tags.
  // Real users are redirected via window.location.replace.
  function sendHtml(res, { title, description, image, redirectUrl }) {
    const safeTitle = title.replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const safeDesc = description.replace(/</g, '&lt;').replace(/>/g, '&gt;');

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${safeTitle}</title>

    <!-- Open Graph / Facebook -->
    <meta property="og:type" content="product">
    <meta property="og:url" content="${redirectUrl}">
    <meta property="og:title" content="${safeTitle}">
    <meta property="og:description" content="${safeDesc}">
    <meta property="og:image" content="${image}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:site_name" content="AgriDirect">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:url" content="${redirectUrl}">
    <meta name="twitter:title" content="${safeTitle}">
    <meta name="twitter:description" content="${safeDesc}">
    <meta name="twitter:image" content="${image}">

    <!-- JS redirect for real users (bots ignore this) -->
    <script>window.location.replace("${redirectUrl}");</script>
</head>
<body>
    <p>Redirecting to <a href="${redirectUrl}">${safeTitle}</a>...</p>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.status(200).send(html);
  }

  // No ID → go to marketplace
  if (!id) {
    sendHtml(res, {
      title: DEFAULT_TITLE,
      description: DEFAULT_DESC,
      image: DEFAULT_IMAGE,
      redirectUrl: `${APP_URL}/marketplace`,
    });
    return;
  }

  const supabaseUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';

  const redirectUrl = `${APP_URL}/product-details?id=${id}`;

  try {
    const response = await fetch(
      `${supabaseUrl}/rest/v1/products?product_id=eq.${id}&select=name,description,price,image_url,product_images(image_url)`,
      {
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`,
        },
      }
    );

    const products = await response.json();
    const product = Array.isArray(products) && products.length > 0 ? products[0] : null;

    if (!product) {
      // Product not found — serve generic OG tags, still redirect to the product page
      sendHtml(res, {
        title: DEFAULT_TITLE,
        description: DEFAULT_DESC,
        image: DEFAULT_IMAGE,
        redirectUrl,
      });
      return;
    }

    const priceFormatted = product.price ? Number(product.price).toFixed(2) : '0.00';
    const title = product.name
      ? `${product.name} - ₱${priceFormatted} | AgriDirect`
      : DEFAULT_TITLE;

    let description = product.description || DEFAULT_DESC;
    if (description.length > 200) description = description.substring(0, 197) + '...';

    // Pick best image: product_images table first, then fallback image_url column
    let image = DEFAULT_IMAGE;
    if (product.product_images && product.product_images.length > 0 && product.product_images[0].image_url) {
      image = product.product_images[0].image_url;
    } else if (product.image_url) {
      image = product.image_url;
    }

    sendHtml(res, { title, description, image, redirectUrl });

  } catch (err) {
    // On any error, still serve OG tags (never 302)
    sendHtml(res, {
      title: DEFAULT_TITLE,
      description: DEFAULT_DESC,
      image: DEFAULT_IMAGE,
      redirectUrl,
    });
  }
}
