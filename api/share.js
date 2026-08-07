export default async function handler(req, res) {
  const { id } = req.query;

  const APP_URL = 'https://agridirect-app.vercel.app';
  const DEFAULT_IMAGE = `${APP_URL}/icons/Icon-512.png`;
  const DEFAULT_TITLE = 'AgriDirect - Farm Direct E-commerce';
  const DEFAULT_DESC = 'Buy fresh, affordable, and high-quality produce directly from farmers on AgriDirect!';

  // IMPORTANT: og:url must be the SHARE url itself — NOT the product-details page.
  // If og:url points to /product-details (Flutter SPA), Facebook follows it,
  // reads the Flutter app's generic meta tags, and overwrites our rich product tags.
  function buildShareUrl(productId) {
    return productId
      ? `${APP_URL}/api/share?id=${productId}`
      : `${APP_URL}/marketplace`;
  }

  // Always serve HTML (never 302) so Facebook reads our OG tags.
  // Real users are redirected by JavaScript; bots ignore JS.
  function sendHtml(res, { title, description, image, redirectUrl, canonicalUrl }) {
    const safeTitle = (title || DEFAULT_TITLE).replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/&(?!amp;|lt;|gt;)/g, '&amp;');
    const safeDesc = (description || DEFAULT_DESC).replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/&(?!amp;|lt;|gt;)/g, '&amp;');
    const safeImage = image || DEFAULT_IMAGE;
    const safeCanonical = canonicalUrl || redirectUrl;

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${safeTitle}</title>

    <!-- Open Graph / Facebook/Messenger -->
    <meta property="og:type" content="product">
    <meta property="og:url" content="${safeCanonical}">
    <meta property="og:title" content="${safeTitle}">
    <meta property="og:description" content="${safeDesc}">
    <meta property="og:image" content="${safeImage}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:site_name" content="AgriDirect">
    <meta property="og:locale" content="en_PH">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:site" content="@agridirect">
    <meta name="twitter:title" content="${safeTitle}">
    <meta name="twitter:description" content="${safeDesc}">
    <meta name="twitter:image" content="${safeImage}">

    <!-- Real users get JS redirect; crawlers/bots ignore JS -->
    <script>
      var ua = navigator.userAgent || '';
      var isCrawler = /facebookexternalhit|Twitterbot|LinkedInBot|WhatsApp|Slackbot/i.test(ua);
      if (!isCrawler) {
        window.location.replace("${redirectUrl}");
      }
    </script>
    <noscript>
      <meta http-equiv="refresh" content="0; url=${redirectUrl}">
    </noscript>
</head>
<body>
    <h1>${safeTitle}</h1>
    <p>${safeDesc}</p>
    <img src="${safeImage}" alt="${safeTitle}" style="max-width:400px">
    <br><a href="${redirectUrl}">View on AgriDirect →</a>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('X-Robots-Tag', 'noindex');
    res.status(200).send(html);
  }

  // No ID → go to marketplace
  if (!id) {
    sendHtml(res, {
      title: DEFAULT_TITLE,
      description: DEFAULT_DESC,
      image: DEFAULT_IMAGE,
      redirectUrl: `${APP_URL}/marketplace`,
      canonicalUrl: `${APP_URL}/marketplace`,
    });
    return;
  }

  const supabaseUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';

  const shareUrl = buildShareUrl(id);        // og:url = this url (not product-details!)
  const redirectUrl = `${APP_URL}/product-details?id=${id}`; // where real users go

  try {
    let product = null;

    // Query v_products VIEW (same view the Flutter app uses)
    try {
      const r1 = await fetch(
        `${supabaseUrl}/rest/v1/v_products?product_id=eq.${encodeURIComponent(id)}&select=name,description,price&limit=1`,
        { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
      );
      const data1 = await r1.json();
      if (Array.isArray(data1) && data1.length > 0) product = data1[0];
    } catch (_) {}

    // Fallback: try the products table directly
    if (!product) {
      try {
        const r2 = await fetch(
          `${supabaseUrl}/rest/v1/products?product_id=eq.${encodeURIComponent(id)}&select=name,description,price&limit=1`,
          { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
        );
        const data2 = await r2.json();
        if (Array.isArray(data2) && data2.length > 0) product = data2[0];
      } catch (_) {}
    }

    // Separately fetch the product image from product_images table
    let imageUrl = DEFAULT_IMAGE;
    try {
      const imgRes = await fetch(
        `${supabaseUrl}/rest/v1/product_images?product_id=eq.${encodeURIComponent(id)}&select=image_url&order=sort_order.asc&limit=1`,
        { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
      );
      const imgData = await imgRes.json();
      if (Array.isArray(imgData) && imgData.length > 0 && imgData[0].image_url) {
        imageUrl = imgData[0].image_url;
      }
    } catch (_) {}

    if (!product) {
      // Product not in DB — serve generic OG but still redirect to product page
      sendHtml(res, {
        title: DEFAULT_TITLE,
        description: DEFAULT_DESC,
        image: DEFAULT_IMAGE,
        redirectUrl,
        canonicalUrl: shareUrl,
      });
      return;
    }

    const priceFormatted = product.price ? Number(product.price).toFixed(2) : null;
    const title = product.name
      ? `${product.name}${priceFormatted ? ' — ₱' + priceFormatted : ''} | AgriDirect`
      : DEFAULT_TITLE;

    let description = product.description || DEFAULT_DESC;
    if (description.length > 200) description = description.substring(0, 197) + '...';

    // Pick best available image (already fetched separately above)
    const image = imageUrl;

    sendHtml(res, {
      title,
      description,
      image,
      redirectUrl,
      canonicalUrl: shareUrl, // ← og:url = share URL, not product-details!
    });

  } catch (err) {
    sendHtml(res, {
      title: DEFAULT_TITLE,
      description: DEFAULT_DESC,
      image: DEFAULT_IMAGE,
      redirectUrl,
      canonicalUrl: shareUrl,
    });
  }
}
