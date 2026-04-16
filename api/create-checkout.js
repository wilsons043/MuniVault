const Stripe = require('stripe');

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

    const { priceId, tierId, cityName, adminEmail, extraSeats, lineItems, successUrl, cancelUrl, billingAnchor } = req.body;

    if (!priceId || !successUrl || !cancelUrl) {
      return res.status(400).json({ error: 'Missing required fields: priceId, successUrl, cancelUrl' });
    }

    // Check for existing customer
    const existingCustomers = await stripe.customers.list({ email: adminEmail, limit: 1 });
    let customerId;
    if (existingCustomers.data.length > 0) {
      customerId = existingCustomers.data[0].id;
    }

    const sessionParams = {
      mode: 'subscription',
      line_items: lineItems || [{ price: priceId, quantity: 1 }],
      success_url: successUrl,
      cancel_url: cancelUrl,
      subscription_data: {
        trial_period_days: 14,
        metadata: {
          tierId: tierId || '',
          cityName: cityName || '',
          adminEmail: adminEmail || '',
          extraSeats: String(extraSeats || 0)
        }
      },
      metadata: {
        tierId: tierId || '',
        cityName: cityName || '',
        adminEmail: adminEmail || ''
      }
    };

    if (customerId) {
      sessionParams.customer = customerId;
    } else if (adminEmail) {
      sessionParams.customer_email = adminEmail;
    }

    if (billingAnchor) {
      sessionParams.subscription_data.billing_cycle_anchor_config = {
        day_of_month: billingAnchor
      };
    }

    const session = await stripe.checkout.sessions.create(sessionParams);

    return res.status(200).json({ url: session.url, sessionId: session.id });
  } catch (err) {
    console.error('Checkout error:', err);
    return res.status(500).json({ error: err.message });
  }
};
