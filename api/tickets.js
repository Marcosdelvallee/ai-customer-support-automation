export default async function handler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET');

    const response = await fetch(
        `${process.env.SUPABASE_URL}/rest/v1/tickets?select=*&order=created_at.desc&limit=100`,
        {
            headers: {
                'apikey': process.env.SUPABASE_KEY,
                'Authorization': `Bearer ${process.env.SUPABASE_KEY}`
            }
        }
    );

    const data = await response.json();
    res.status(200).json(data);
}