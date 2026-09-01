export default async function handler(req, res) {
  const { id, type } = req.query;

  const APP_URL = 'https://agridirect-app.vercel.app';
  const DEFAULT_IMAGE = `${APP_URL}/icons/Icon-512.png`;
  const DEFAULT_TITLE = 'AgriDirect - Farm Direct E-commerce';
  const DEFAULT_DESC = 'Buy fresh, affordable, and high-quality produce directly from local farmers on AgriDirect!';

  const supabaseUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';

  function resolveImageUrl(url) {
    if (!url) return DEFAULT_IMAGE;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return `${supabaseUrl}/storage/v1/object/public/uploads/${url}`;
  }

  // Always serve HTML so crawlers (Facebook, Messenger, Twitter, etc.) read the OpenGraph tags.
  function sendHtml(res, { title, description, image, redirectUrl, canonicalUrl }) {
    const safeTitle = (title || DEFAULT_TITLE).replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/&(?!amp;|lt;|gt;)/g, '&amp;');
    const safeDesc = (description || DEFAULT_DESC).replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/&(?!amp;|lt;|gt;)/g, '&amp;');
    const safeImage = resolveImageUrl(image);
    const safeCanonical = canonicalUrl || redirectUrl;

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${safeTitle}</title>

    <!-- Open Graph / Facebook / Messenger / WhatsApp -->
    <meta property="og:type" content="website">
    <meta property="og:url" content="${safeCanonical}">
    <meta property="og:title" content="${safeTitle}">
    <meta property="og:description" content="${safeDesc}">
    <meta property="og:image" content="${safeImage}">
    <meta property="og:image:secure_url" content="${safeImage}">
    <meta property="og:image:width" content="600">
    <meta property="og:image:height" content="600">
    <meta property="og:site_name" content="AgriDirect Philippines">
    <meta property="og:locale" content="en_PH">

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:site" content="@agridirect">
    <meta name="twitter:title" content="${safeTitle}">
    <meta name="twitter:description" content="${safeDesc}">
    <meta name="twitter:image" content="${safeImage}">

    <!-- Real users get JS redirect; crawlers/bots stay to read metadata -->
    <script>
      var ua = navigator.userAgent || '';
      var isCrawler = /facebookexternalhit|Facebot|Twitterbot|LinkedInBot|WhatsApp|Slackbot|TelegramBot|Discordbot|Applebot|Googlebot|bingbot|SkypeUriPreview/i.test(ua);
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

  // Handle FARMER profile sharing
  if (type === 'farmer') {
    const shareUrl = `${APP_URL}/farmer/${id}`;
    const redirectUrl = `${APP_URL}/farm/${id}`;

    try {
      let farmer = null;
      let avatarUrl = null;

      // 1. Fetch farmer details (support either farmer_id or user_id)
      try {
        const r1 = await fetch(
          `${supabaseUrl}/rest/v1/farmers?or=(farmer_id.eq.${encodeURIComponent(id)},user_id.eq.${encodeURIComponent(id)})&select=farmer_id,user_id,farm_name,specialty,image_url,is_verified&limit=1`,
          { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
        );
        const data1 = await r1.json();
        if (Array.isArray(data1) && data1.length > 0) farmer = data1[0];
      } catch (_) {}

      // 2. Fetch User Avatar (Farm Logo) from users table
      const targetUserId = farmer?.user_id || id;
      if (targetUserId) {
        try {
          const r2 = await fetch(
            `${supabaseUrl}/rest/v1/users?id=eq.${encodeURIComponent(targetUserId)}&select=name,avatar_url&limit=1`,
            { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
          );
          const data2 = await r2.json();
          if (Array.isArray(data2) && data2.length > 0) {
            avatarUrl = data2[0].avatar_url;
            if (!farmer) {
              farmer = { farm_name: data2[0].name };
            } else if (!farmer.farm_name) {
              farmer.farm_name = data2[0].name;
            }
          }
        } catch (_) {}
      }

      if (!farmer && !avatarUrl) {
        sendHtml(res, {
          title: DEFAULT_TITLE,
          description: DEFAULT_DESC,
          image: DEFAULT_IMAGE,
          redirectUrl,
          canonicalUrl: shareUrl,
        });
        return;
      }

      const farmName = farmer?.farm_name || 'Local Farm';
      const title = `${farmName} | AgriDirect Farm Store`;
      const description = farmer?.specialty 
        ? `Specializing in ${farmer.specialty}. Fresh harvest available directly from ${farmName} on AgriDirect!`
        : `Check out ${farmName} on AgriDirect! Order fresh produce and support local Filipino growers directly.`;
      const image = avatarUrl || farmer?.image_url || DEFAULT_IMAGE;

      sendHtml(res, {
        title,
        description,
        image,
        redirectUrl,
        canonicalUrl: shareUrl,
      });
      return;
    } catch (e) {
      sendHtml(res, {
        title: DEFAULT_TITLE,
        description: DEFAULT_DESC,
        image: DEFAULT_IMAGE,
        redirectUrl,
        canonicalUrl: shareUrl,
      });
      return;
    }
  }

  // Handle PRODUCT sharing (Default)
  const shareUrl = `${APP_URL}/product/${id}`;
  const redirectUrl = `${APP_URL}/product-details?id=${id}`;

  try {
    let product = null;

    // Query v_products VIEW
    try {
      const r1 = await fetch(
        `${supabaseUrl}/rest/v1/v_products?product_id=eq.${encodeURIComponent(id)}&select=name,description,price&limit=1`,
        { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
      );
      const data1 = await r1.json();
      if (Array.isArray(data1) && data1.length > 0) product = data1[0];
    } catch (_) {}

    // Fallback: try products table
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

    sendHtml(res, {
      title,
      description,
      image: imageUrl,
      redirectUrl,
      canonicalUrl: shareUrl,
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
