(() => {
  "use strict";

  const config = window.LEGADO_SUPABASE;
  const L = window.Legado;
  if (!config?.url || !config?.anonKey || !L) return;

  const projectBase = config.url.replace(/\/rest\/v1\/?$/, "").replace(/\/$/, "");
  const apiBase = projectBase + "/rest/v1";
  const authBase = projectBase + "/auth/v1";
  const storageBase = projectBase + "/storage/v1";
  const functionsBase = projectBase + "/functions/v1";
  const SESSION_KEY = "legadoSupabaseSession";
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  let syncingFromSupabase = false;

  const original = {
    setSettings: L.setSettings,
    setServices: L.setServices,
    setAvailability: L.setAvailability,
    setBlocks: L.setBlocks,
    setPortfolio: L.setPortfolio,
    setTestimonials: L.setTestimonials,
    setClients: L.setClients,
    setProducts: L.setProducts,
    setPayments: L.setPayments,
    setCommissions: L.setCommissions,
    setSettlements: L.setSettlements,
    setInventoryMovements: L.setInventoryMovements,
    setProductSales: L.setProductSales,
    setCashRegisters: L.setCashRegisters,
    upsertClient: L.upsertClient,
    upsertProduct: L.upsertProduct,
    upsertInventoryMovement: L.upsertInventoryMovement,
    upsertProductSale: L.upsertProductSale,
    upsertCashRegister: L.upsertCashRegister,
    upsertPayment: L.upsertPayment,
    upsertCommission: L.upsertCommission,
    upsertSettlement: L.upsertSettlement,
    saveClientProfile: L.saveClientProfile,
    reserveBookingOnline: L.reserveBookingOnline,
    submitTestimonialOnline: L.submitTestimonialOnline,
    loadRemoteBookingsForDate: L.loadRemoteBookingsForDate,
    setBookings: L.setBookings,
    upsertBooking: L.upsertBooking,
    deleteBooking: L.deleteBooking,
    reserveBooking: L.reserveBooking,
    confirmBooking: L.confirmBooking,
    restoreBackup: L.restoreBackup
  };

  function readSession() {
    try { return JSON.parse(sessionStorage.getItem(SESSION_KEY) || localStorage.getItem(SESSION_KEY) || "null"); }
    catch { return null; }
  }

  function accessToken() {
    const session = readSession();
    return session?.access_token || "";
  }

  function refreshToken() {
    const session = readSession();
    return session?.refresh_token || "";
  }

  function headers(extra = {}) {
    const token = accessToken() || config.anonKey;
    return {
      apikey: config.anonKey,
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      "Content-Type": "application/json",
      ...extra
    };
  }

  function stableUuid(value) {
    const text = String(value || "");
    if (uuidPattern.test(text)) return text;
    let hash1 = 2166136261;
    let hash2 = 2166136261;
    for (let index = 0; index < text.length; index += 1) {
      hash1 ^= text.charCodeAt(index);
      hash1 = Math.imul(hash1, 16777619);
      hash2 ^= text.charCodeAt(text.length - 1 - index);
      hash2 = Math.imul(hash2, 16777619);
    }
    const hex = `${(hash1 >>> 0).toString(16).padStart(8, "0")}${(hash2 >>> 0).toString(16).padStart(8, "0")}${Math.abs(text.length * 2654435761 >>> 0).toString(16).padStart(8, "0")}${Math.abs((hash1 ^ hash2) >>> 0).toString(16).padStart(8, "0")}`.slice(0, 32);
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-8${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
  }

  function cleanTime(value) {
    return String(value || "00:00").slice(0, 5);
  }

  function writeLocal(key, value) {
    syncingFromSupabase = true;
    try {
      localStorage.setItem(key, JSON.stringify(value));
      window.dispatchEvent(new CustomEvent("legado:datachange", { detail: { key, source: "supabase" } }));
    } finally {
      syncingFromSupabase = false;
    }
  }

  async function request(path, options = {}) {
    const response = await fetch(`${apiBase}/${path}`, { ...options, headers: headers(options.headers) });
    if (!response.ok) {
      const detail = await response.text().catch(() => "");
      throw new Error(`Supabase ${response.status}: ${detail || path}`);
    }
    if (response.status === 204) return null;
    return response.json();
  }

  async function authRequest(path, options = {}) {
    const response = await fetch(`${authBase}/${path}`, { ...options, headers: headers(options.headers) });
    if (!response.ok) {
      const detail = await response.text().catch(() => "");
      throw new Error(`Supabase Auth ${response.status}: ${detail || path}`);
    }
    if (response.status === 204) return null;
    return response.json().catch(() => null);
  }

  async function storageRequest(path, options = {}) {
    const response = await fetch(`${storageBase}/${path}`, {
      ...options,
      headers: headers({ "Content-Type": options.body?.type || "application/octet-stream", ...(options.headers || {}) })
    });
    if (!response.ok) {
      const detail = await response.text().catch(() => "");
      throw new Error(`Supabase Storage ${response.status}: ${detail || path}`);
    }
    if (response.status === 204) return null;
    return response.json().catch(() => null);
  }

  async function functionRequest(name, payload = {}) {
    const response = await fetch(`${functionsBase}/${name}`, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify(payload)
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok || body?.ok === false) throw new Error(body?.error || `Edge Function ${name} falhou.`);
    return body;
  }

  function isImageDataUrl(value) {
    return /^data:image\/(png|jpe?g|webp);base64,/i.test(String(value || ""));
  }

  function dataUrlToBlob(dataUrl) {
    const [meta, base64] = String(dataUrl || "").split(",");
    const contentType = meta.match(/^data:([^;]+)/i)?.[1] || "image/jpeg";
    const binary = atob(base64 || "");
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    return new Blob([bytes], { type: contentType });
  }

  async function uploadClientPhoto(client) {
    if (!isImageDataUrl(client.photo)) return client.photo || "";
    const blob = dataUrlToBlob(client.photo);
    const extension = blob.type.includes("png") ? "png" : blob.type.includes("webp") ? "webp" : "jpg";
    const phoneDigits = L.normalizePhone(client.phoneDigits || client.phone);
    const path = `${encodeURIComponent(phoneDigits || stableUuid(client.id))}/profile.${extension}`;
    await storageRequest(`object/client-photos/${path}`, {
      method: "POST",
      headers: { "x-upsert": "true" },
      body: blob
    });
    return `${storageBase}/object/public/client-photos/${path}`;
  }

  async function findClientRowByPhone(phoneDigits) {
    const digits = L.normalizePhone(phoneDigits);
    if (!digits) return null;
    const rows = await request("rpc/lookup_client_profile", {
      method: "POST",
      body: JSON.stringify({ p_phone_digits: digits })
    });
    return rows?.[0] || null;
  }

  async function fetchActiveBookingsForDate(date, professional = "") {
    let rows;
    try {
      rows = await request("rpc/booked_intervals_for_professional", {
        method: "POST",
        body: JSON.stringify({ p_date: date, p_professional: professional || L.getSettings().professional })
      });
    } catch (error) {
      rows = await request("rpc/booked_intervals", {
        method: "POST",
        body: JSON.stringify({ p_date: date })
      });
    }
    return (rows || []).map((row, index) => L.normalizeBooking({
      id: `remote-${date}-${cleanTime(row.start_time)}-${index}`,
      code: "OCUPADO",
      service: "Horário reservado",
      durationMinutes: Math.max(5, L.timeToMinutes(cleanTime(row.end_time)) - L.timeToMinutes(cleanTime(row.start_time))),
      date,
      startTime: cleanTime(row.start_time),
      time: cleanTime(row.start_time),
      endTime: cleanTime(row.end_time),
      name: "Cliente Legado",
      phone: "",
      professional: row.professional || professional || "",
      status: "confirmed",
      source: "supabase"
    }));
  }

  async function upsert(table, rows, uuidId = false) {
    const list = (Array.isArray(rows) ? rows : [rows]).filter(Boolean);
    if (!list.length) return [];
    const body = list.map(row => uuidId && row.id ? { ...row, id: stableUuid(row.id) } : row);
    return request(`${table}?on_conflict=id`, {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=representation" },
      body: JSON.stringify(body)
    });
  }

  async function upsertMinimal(table, rows, uuidId = false) {
    const list = (Array.isArray(rows) ? rows : [rows]).filter(Boolean);
    if (!list.length) return [];
    const body = list.map(row => uuidId && row.id ? { ...row, id: stableUuid(row.id) } : row);
    await request(`${table}?on_conflict=id`, {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify(body)
    });
    return body;
  }

  async function removeRows(table, ids, uuidId = false) {
    const list = (Array.isArray(ids) ? ids : [ids]).filter(Boolean);
    await Promise.all(list.map(id => request(`${table}?id=eq.${encodeURIComponent(uuidId ? stableUuid(id) : id)}`, { method: "DELETE", headers: { Prefer: "return=minimal" } })));
  }

  function syncQuietly(work) {
    if (syncingFromSupabase) return;
    Promise.resolve().then(work).catch(error => console.warn("Legado Supabase:", error.message));
  }

  function serviceRow(service, index = 0) {
    const item = L.normalizeService(service, index);
    return { id: item.id, name: item.name, description: item.description, duration_minutes: item.durationMinutes, price: item.price, icon: item.icon, active: item.active, sort_order: index + 1 };
  }

  function settingsRow(settings) {
    return { id: "main", data: { ...L.getSettings(), ...(settings || {}) }, updated_at: new Date().toISOString() };
  }

  function barberRowsFromSettings(settings = L.getSettings()) {
    const names = Array.isArray(settings.barbers) && settings.barbers.length ? settings.barbers : [settings.professional];
    return names.map((name, index) => {
      const profile = settings.barberProfiles?.[name] || settings.barberProfiles?.[L.slugify(name)] || {};
      return {
        id: stableUuid(`barber-${L.slugify(name || `profissional-${index}`)}`),
        full_name: profile.fullName || name,
        display_name: name,
        phone: profile.phone || "",
        email: profile.email || "",
        photo_url: settings.barberPhotos?.[name] || settings.barberPhotos?.[L.slugify(name)] || "",
        bio: profile.bio || "",
        service_commission: Number(settings.barberCommissions?.[name] ?? settings.barberCommissions?.[L.slugify(name)] ?? 0) || 0,
        product_commission: Number(profile.productCommission || 0) || 0,
        active: profile.active !== false,
        show_on_site: profile.showOnSite !== false && profile.active !== false,
        sort_order: index + 1,
        created_at: profile.createdAt || new Date().toISOString(),
        updated_at: new Date().toISOString()
      };
    });
  }

  function availabilityRow(value) {
    return { id: "main", data: L.getAvailability(value), updated_at: new Date().toISOString() };
  }

  function blockRow(block) {
    const item = { ...block };
    return { id: stableUuid(item.id), date: item.date, all_day: Boolean(item.allDay), start_time: item.startTime || "00:00", end_time: item.endTime || "23:59", reason: item.reason || "Horario bloqueado", created_at: item.createdAt || new Date().toISOString() };
  }

  function bookingRow(booking) {
    const item = L.normalizeBooking(booking);
    return {
      id: stableUuid(item.id), code: item.code, service_id: item.serviceId || null, service_name: item.service,
      duration_minutes: item.durationMinutes, price_value: item.priceValue, booking_date: item.date,
      start_time: item.startTime, end_time: item.endTime, client_name: item.name, client_phone: item.phone,
      phone_digits: item.phoneDigits, client_photo: item.clientPhoto || "", professional: item.professional, notes: item.notes, status: item.status,
      source: item.source, cancellation_reason: item.cancellationReason || null,
      created_at: item.createdAt, updated_at: item.updatedAt || new Date().toISOString()
    };
  }

  function clientRow(client) {
    const item = L.normalizeClient(client);
    return {
      id: stableUuid(item.id || item.phoneDigits),
      client_name: item.name,
      client_phone: item.phone,
      phone_digits: item.phoneDigits,
      profile_photo: item.photo || "",
      notes: item.notes || "",
      is_existing_customer: Boolean(item.existingCustomer),
      first_seen_at: item.firstSeenAt || new Date().toISOString(),
      last_seen_at: item.lastSeenAt || new Date().toISOString(),
      created_at: item.createdAt || new Date().toISOString(),
      updated_at: item.updatedAt || new Date().toISOString()
    };
  }

  function portfolioRow(item, index = 0) {
    const normalized = L.normalizePortfolioItem(item, index);
    const gallery = Array.isArray(normalized.images) && normalized.images.length ? normalized.images : [normalized.image].filter(Boolean);
    return {
      id: stableUuid(normalized.id),
      title: normalized.title,
      category: normalized.category,
      summary: normalized.summary || normalized.description,
      description: normalized.description || normalized.summary,
      image_url: normalized.image,
      gallery_images: [...new Set(gallery.filter(Boolean))],
      image_position_x: normalized.imagePositionX,
      image_position_y: normalized.imagePositionY,
      image_zoom: normalized.imageZoom,
      alt_text: normalized.alt,
      featured: normalized.featured,
      active: normalized.active,
      sort_order: normalized.order || index + 1,
      created_at: normalized.createdAt || new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
  }

  function portfolioLegacyRow(item, index = 0) {
    const normalized = L.normalizePortfolioItem(item, index);
    return {
      id: stableUuid(normalized.id),
      title: normalized.title,
      category: normalized.category,
      description: normalized.description || normalized.summary,
      image_url: normalized.image,
      alt_text: normalized.alt,
      featured: normalized.featured,
      active: normalized.active,
      sort_order: normalized.order || index + 1,
      created_at: normalized.createdAt || new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
  }

  function testimonialRow(item, index = 0) {
    const normalized = L.normalizeTestimonial(item, index);
    return { id: stableUuid(normalized.id), client_name: normalized.name, client_phone: normalized.phone || "", phone_digits: normalized.phoneDigits || "", service_name: normalized.service, testimonial: normalized.text, rating: normalized.rating, profile_photo: normalized.photo || "", status: normalized.status || "pending", active: normalized.active, source: normalized.source || "admin", sort_order: normalized.order || index + 1, created_at: normalized.createdAt || new Date().toISOString(), updated_at: normalized.updatedAt || new Date().toISOString() };
  }

  function productRow(item, index = 0) {
    const normalized = L.normalizeProduct(item, index);
    return {
      id: stableUuid(normalized.id),
      name: normalized.name,
      description: normalized.description,
      category: normalized.category,
      image_url: normalized.image || "",
      cost_price: normalized.cost,
      sale_price: normalized.price,
      quantity: normalized.quantity,
      minimum_stock: normalized.minStock,
      internal_code: normalized.code,
      barber_commission: normalized.barberCommission,
      active: normalized.active,
      created_at: normalized.createdAt || new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
  }

  function inventoryMovementRow(item, index = 0) {
    const normalized = L.normalizeInventoryMovement(item, index);
    return {
      id: stableUuid(normalized.id),
      product_id: normalized.productId ? stableUuid(normalized.productId) : null,
      movement_type: normalized.type,
      quantity: normalized.quantity,
      reason: [normalized.productName ? `Produto: ${normalized.productName}` : "", normalized.reason || ""].filter(Boolean).join(" | "),
      created_at: normalized.createdAt || new Date().toISOString()
    };
  }

  function productSaleRow(item, index = 0) {
    const normalized = L.normalizeProductSale(item, index);
    return {
      id: stableUuid(normalized.id),
      product_id: normalized.productId ? stableUuid(normalized.productId) : null,
      payment_id: normalized.paymentId ? stableUuid(normalized.paymentId) : null,
      product_name: normalized.productName,
      quantity: normalized.quantity,
      unit_price: normalized.unitPrice,
      total_amount: normalized.totalAmount,
      payment_method: normalized.paymentMethod,
      notes: normalized.notes,
      created_at: normalized.createdAt || new Date().toISOString()
    };
  }

  function cashRegisterRow(item, index = 0) {
    const normalized = L.normalizeCashRegister(item, index);
    return {
      id: stableUuid(normalized.id),
      register_date: normalized.date,
      opening_amount: normalized.openingAmount,
      closing_amount: normalized.closingAmount,
      expected_amount: normalized.expectedAmount,
      status: normalized.status,
      opened_at: normalized.openedAt || new Date().toISOString(),
      closed_at: normalized.closedAt || null,
      notes: normalized.notes || ""
    };
  }

  function paymentRow(item, index = 0) {
    const normalized = L.normalizePayment(item, index);
    return {
      id: stableUuid(normalized.id),
      booking_id: normalized.bookingId ? stableUuid(normalized.bookingId) : null,
      client_id: normalized.clientId && uuidPattern.test(normalized.clientId) ? normalized.clientId : null,
      barber_id: normalized.barberId && uuidPattern.test(normalized.barberId) ? normalized.barberId : null,
      gross_amount: normalized.grossAmount,
      discount_amount: normalized.discountAmount,
      fee_amount: normalized.feeAmount,
      net_amount: normalized.netAmount,
      payment_method: normalized.method,
      status: normalized.status,
      notes: normalized.notes,
      created_at: normalized.createdAt || new Date().toISOString(),
      updated_at: normalized.updatedAt || new Date().toISOString()
    };
  }

  function commissionRow(item, index = 0) {
    const normalized = L.normalizeCommission(item, index);
    return {
      id: stableUuid(normalized.id),
      barber_id: normalized.barberId && uuidPattern.test(normalized.barberId) ? normalized.barberId : null,
      booking_id: normalized.bookingId ? stableUuid(normalized.bookingId) : null,
      payment_id: normalized.paymentId ? stableUuid(normalized.paymentId) : null,
      base_amount: normalized.baseAmount,
      commission_percent: normalized.commissionPercent,
      commission_amount: normalized.commissionAmount,
      status: normalized.status,
      created_at: normalized.createdAt || new Date().toISOString(),
      updated_at: normalized.updatedAt || new Date().toISOString()
    };
  }

  function settlementRow(item, index = 0) {
    const normalized = L.normalizeSettlement(item, index);
    return {
      id: stableUuid(normalized.id),
      barber_id: normalized.barberId && uuidPattern.test(normalized.barberId) ? normalized.barberId : null,
      period_start: normalized.periodStart || new Date().toISOString().slice(0, 10),
      period_end: normalized.periodEnd || new Date().toISOString().slice(0, 10),
      gross_amount: normalized.grossAmount,
      commission_amount: normalized.commissionAmount,
      paid_amount: normalized.paidAmount,
      status: normalized.status,
      notes: [normalized.barberName ? `Barbeiro: ${normalized.barberName}` : "", normalized.notes || ""].filter(Boolean).join(" | "),
      created_at: normalized.createdAt || new Date().toISOString(),
      updated_at: normalized.updatedAt || new Date().toISOString()
    };
  }

  function mapService(row) {
    return L.normalizeService({ id: row.id, name: row.name, description: row.description, durationMinutes: row.duration_minutes, price: row.price, icon: row.icon, active: row.active });
  }

  function mapBlock(row) {
    return { id: row.id, date: row.date, allDay: row.all_day, startTime: cleanTime(row.start_time), endTime: cleanTime(row.end_time), reason: row.reason, createdAt: row.created_at };
  }

  function mapBooking(row) {
    return L.normalizeBooking({ id: row.id, code: row.code, serviceId: row.service_id, service: row.service_name, durationMinutes: row.duration_minutes, priceValue: row.price_value, date: row.booking_date, startTime: cleanTime(row.start_time), time: cleanTime(row.start_time), endTime: cleanTime(row.end_time), name: row.client_name, phone: row.client_phone, phoneDigits: row.phone_digits, clientPhoto: row.client_photo, professional: row.professional, notes: row.notes, status: row.status, source: row.source, cancellationReason: row.cancellation_reason, createdAt: row.created_at, updatedAt: row.updated_at });
  }

  function mapClient(row, index) {
    return L.normalizeClient({ id: row.id || row.phone_digits || `client-${index}`, name: row.client_name, phone: row.client_phone, phoneDigits: row.phone_digits, photo: row.profile_photo, notes: row.notes, existingCustomer: row.is_existing_customer, firstSeenAt: row.first_seen_at, lastSeenAt: row.last_seen_at, createdAt: row.created_at, updatedAt: row.updated_at }, index);
  }

  function mapPortfolio(row, index) {
    const gallery = Array.isArray(row.gallery_images) ? row.gallery_images : [];
    const images = [...new Set([row.image_url, ...gallery].filter(Boolean))];
    return L.normalizePortfolioItem({
      id: row.id,
      title: row.title,
      category: row.category,
      summary: row.summary || row.description,
      description: row.description || row.summary,
      image: row.image_url || images[0],
      images,
      imagePositionX: row.image_position_x,
      imagePositionY: row.image_position_y,
      imageZoom: row.image_zoom,
      alt: row.alt_text,
      featured: row.featured,
      active: row.active,
      order: row.sort_order || index + 1,
      createdAt: row.created_at
    }, index);
  }

  async function upsertPortfolioRows(items) {
    const rows = items.map(portfolioRow);
    try {
      await upsert("portfolio", rows, true);
    } catch (error) {
      if (!/summary|gallery_images|image_position_x|image_position_y|image_zoom|schema cache/i.test(error.message || "")) throw error;
      console.warn("Legado Supabase: rode o SQL atualizado para salvar galeria e enquadramento do portfolio.", error.message);
      await upsert("portfolio", items.map(portfolioLegacyRow), true);
    }
  }

  function mapTestimonial(row, index) {
    return L.normalizeTestimonial({ id: row.id, name: row.client_name, phone: row.client_phone, phoneDigits: row.phone_digits, service: row.service_name, text: row.testimonial, rating: row.rating, photo: row.profile_photo, status: row.status, active: row.active, source: row.source, order: row.sort_order || index + 1, createdAt: row.created_at, updatedAt: row.updated_at }, index);
  }

  function mapProduct(row, index) {
    return L.normalizeProduct({ id: row.id, name: row.name, description: row.description, category: row.category, image: row.image_url, cost: row.cost_price, price: row.sale_price, quantity: row.quantity, minStock: row.minimum_stock, code: row.internal_code, barberCommission: row.barber_commission, active: row.active, createdAt: row.created_at, updatedAt: row.updated_at }, index);
  }

  function mergeBarbersIntoSettings(rows = []) {
    if (!Array.isArray(rows) || !rows.length) return;
    const settings = L.getSettings();
    const names = rows.map(row => row.display_name || row.full_name).filter(Boolean);
    const barberPhotos = { ...(settings.barberPhotos || {}) };
    const barberCommissions = { ...(settings.barberCommissions || {}) };
    const barberProfiles = { ...(settings.barberProfiles || {}) };
    rows.forEach(row => {
      const name = row.display_name || row.full_name;
      if (!name) return;
      if (row.photo_url) barberPhotos[name] = row.photo_url;
      barberCommissions[name] = Number(row.service_commission || 0);
      barberProfiles[name] = {
        ...(barberProfiles[name] || {}),
        fullName: row.full_name || name,
        phone: row.phone || "",
        email: row.email || "",
        bio: row.bio || "",
        active: row.active !== false,
        showOnSite: row.show_on_site !== false,
        productCommission: Number(row.product_commission || 0),
        createdAt: row.created_at,
        updatedAt: row.updated_at
      };
    });
    writeLocal(L.KEYS.settings, { ...settings, barbers: [...new Set([settings.professional, ...settings.barbers, ...names].filter(Boolean))], barberPhotos, barberCommissions, barberProfiles });
  }

  function mapInventoryMovement(row, index) {
    const productName = String(row.reason || "").match(/Produto:\s*([^|]+)/)?.[1]?.trim() || "";
    return L.normalizeInventoryMovement({ id: row.id, productId: row.product_id, productName, type: row.movement_type, quantity: row.quantity, reason: row.reason, createdAt: row.created_at }, index);
  }

  function mapProductSale(row, index) {
    return L.normalizeProductSale({ id: row.id, productId: row.product_id, paymentId: row.payment_id, productName: row.product_name, quantity: row.quantity, unitPrice: row.unit_price, totalAmount: row.total_amount, paymentMethod: row.payment_method, notes: row.notes, createdAt: row.created_at }, index);
  }

  function mapCashRegister(row, index) {
    return L.normalizeCashRegister({ id: row.id, date: row.register_date, openingAmount: row.opening_amount, closingAmount: row.closing_amount, expectedAmount: row.expected_amount, status: row.status, notes: row.notes, openedAt: row.opened_at, closedAt: row.closed_at }, index);
  }

  function mapPayment(row, index) {
    return L.normalizePayment({ id: row.id, bookingId: row.booking_id, clientId: row.client_id, barberId: row.barber_id, grossAmount: row.gross_amount, discountAmount: row.discount_amount, feeAmount: row.fee_amount, netAmount: row.net_amount, method: row.payment_method, status: row.status, notes: row.notes, createdAt: row.created_at, updatedAt: row.updated_at }, index);
  }

  function mapCommission(row, index) {
    return L.normalizeCommission({ id: row.id, barberId: row.barber_id, bookingId: row.booking_id, paymentId: row.payment_id, baseAmount: row.base_amount, commissionPercent: row.commission_percent, commissionAmount: row.commission_amount, status: row.status, createdAt: row.created_at, updatedAt: row.updated_at }, index);
  }

  function mapSettlement(row, index) {
    const barberName = String(row.notes || "").match(/Barbeiro:\s*([^|]+)/)?.[1]?.trim() || "";
    return L.normalizeSettlement({ id: row.id, barberId: row.barber_id, barberName, periodStart: row.period_start, periodEnd: row.period_end, grossAmount: row.gross_amount, commissionAmount: row.commission_amount, paidAmount: row.paid_amount, status: row.status, notes: row.notes, createdAt: row.created_at, updatedAt: row.updated_at }, index);
  }

  async function signIn(email, password) {
    const response = await fetch(`${authBase}/token?grant_type=password`, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify({ email, password })
    });
    if (!response.ok) return { ok: false, error: "E-mail ou senha recusados pelo Supabase." };
    const session = await response.json();
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
    try {
      const profile = await getAdminProfile();
      if (!profile) {
        signOut();
        return { ok: false, error: "Este usuário não tem perfil autorizado para o painel." };
      }
      await hydrateFromSupabase();
      return { ok: true, session, profile };
    } catch (error) {
      signOut();
      return { ok: false, error: error.message || "Não foi possível validar o acesso ao painel." };
    }
  }

  function signOut() {
    const token = accessToken();
    if (token) authRequest("logout", { method: "POST" }).catch(error => console.warn("Legado Supabase:", error.message));
    sessionStorage.removeItem(SESSION_KEY);
    localStorage.removeItem(SESSION_KEY);
  }

  async function getCurrentUser() {
    if (!accessToken()) return null;
    const user = await authRequest("user");
    return user || null;
  }

  async function getAdminProfile() {
    const user = await getCurrentUser();
    if (!user?.id) return null;
    const rows = await request(`profiles?select=id,name,role&id=eq.${encodeURIComponent(user.id)}&limit=1`);
    const profile = rows?.[0] || null;
    return profile && ["owner", "admin", "barber"].includes(profile.role) ? profile : null;
  }

  async function hasAdminSession() {
    if (!accessToken()) return false;
    try {
      return Boolean(await getAdminProfile());
    } catch (error) {
      console.warn("Legado Supabase:", error.message);
      signOut();
      return false;
    }
  }

  async function createBarberAccess(payload) {
    return functionRequest("manage-barber-access", payload);
  }

  async function hydrateFromSupabase() {
    const publicRequests = [
      request("business_settings?select=data&id=eq.main&limit=1"),
      request("availability?select=data&id=eq.main&limit=1"),
      request("services?select=*&order=sort_order.asc,name.asc"),
      request("portfolio?select=*&active=eq.true&order=sort_order.asc,created_at.desc"),
      request("testimonials?select=*&active=eq.true&order=sort_order.asc,created_at.desc")
    ];
    const [settingsRows, availabilityRows, servicesRows, portfolioRows, testimonialRows] = await Promise.all(publicRequests);
    if (settingsRows[0]?.data && Object.keys(settingsRows[0].data).length) writeLocal(L.KEYS.settings, settingsRows[0].data);
    if (availabilityRows[0]?.data && Object.keys(availabilityRows[0].data).length) writeLocal(L.KEYS.availability, availabilityRows[0].data);
    if (servicesRows.length) writeLocal(L.KEYS.services, servicesRows.map(mapService));
    if (portfolioRows.length) writeLocal(L.KEYS.portfolio, portfolioRows.map(mapPortfolio));
    if (testimonialRows.length) writeLocal(L.KEYS.testimonials, testimonialRows.map(mapTestimonial));

    if (accessToken()) {
      const [blockRows, bookingRows, clientRows, allPortfolioRows, allTestimonialRows, barberRows, productRows, inventoryRows, productSaleRows, paymentRows, cashRows, commissionRows, settlementRows] = await Promise.all([
        request("blocked_slots?select=*&order=date.asc,start_time.asc").catch(error => {
          console.warn("Legado Supabase: sem permissao para sincronizar bloqueios.", error.message);
          return [];
        }),
        request("bookings?select=*&order=booking_date.asc,start_time.asc").catch(error => {
          console.warn("Legado Supabase: sem permissao para sincronizar todos os agendamentos.", error.message);
          return [];
        }),
        request("clients?select=*&order=updated_at.desc").catch(error => {
          console.warn("Legado Supabase: sem permissao para sincronizar todos os clientes.", error.message);
          return [];
        }),
        request("portfolio?select=*&order=sort_order.asc,created_at.desc"),
        request("testimonials?select=*&order=created_at.desc"),
        request("barbers?select=*&order=sort_order.asc,display_name.asc").catch(error => {
          console.warn("Legado Supabase: rode o SQL atualizado para sincronizar barbeiros.", error.message);
          return [];
        }),
        request("products?select=*&order=name.asc").catch(error => {
          console.warn("Legado Supabase: rode o SQL atualizado para sincronizar produtos.", error.message);
          return [];
        }),
        request("inventory_movements?select=*&order=created_at.desc").catch(error => {
          console.warn("Legado Supabase: rode o SQL atualizado para sincronizar estoque.", error.message);
          return [];
        }),
        request("product_sales?select=*&order=created_at.desc").catch(error => {
          console.warn("Legado Supabase: rode o SQL atualizado para sincronizar vendas de produtos.", error.message);
          return [];
        }),
        request("payments?select=*&order=created_at.desc").catch(error => {
          console.warn("Legado Supabase: rode o SQL atualizado para sincronizar pagamentos.", error.message);
          return [];
        }),
        request("cash_registers?select=*&order=register_date.desc,opened_at.desc").catch(error => {
          console.warn("Legado Supabase: rode o SQL atualizado para sincronizar caixa.", error.message);
          return [];
        }),
        request("commissions?select=*&order=created_at.desc").catch(error => {
          console.warn("Legado Supabase: rode o SQL atualizado para sincronizar comissões.", error.message);
          return [];
        }),
        request("barber_settlements?select=*&order=created_at.desc").catch(error => {
          console.warn("Legado Supabase: rode o SQL atualizado para sincronizar fechamentos.", error.message);
          return [];
        })
      ]);
      writeLocal(L.KEYS.blocks, blockRows.map(mapBlock));
      writeLocal(L.KEYS.bookings, bookingRows.map(mapBooking));
      writeLocal(L.KEYS.clients, clientRows.map(mapClient));
      writeLocal(L.KEYS.portfolio, allPortfolioRows.map(mapPortfolio));
      writeLocal(L.KEYS.testimonials, allTestimonialRows.map(mapTestimonial));
      mergeBarbersIntoSettings(barberRows);
      if (productRows.length) writeLocal(L.KEYS.products, productRows.map(mapProduct));
      if (inventoryRows.length) writeLocal(L.KEYS.inventoryMovements, inventoryRows.map(mapInventoryMovement));
      if (productSaleRows.length) writeLocal(L.KEYS.productSales, productSaleRows.map(mapProductSale));
      if (paymentRows.length) writeLocal(L.KEYS.payments, paymentRows.map(mapPayment));
      if (cashRows.length) writeLocal(L.KEYS.cashRegisters, cashRows.map(mapCashRegister));
      if (commissionRows.length) writeLocal(L.KEYS.commissions, commissionRows.map(mapCommission));
      if (settlementRows.length) writeLocal(L.KEYS.settlements, settlementRows.map(mapSettlement));
    }
  }

  L.setSettings = function setSettings(settings) {
    original.setSettings(settings);
    syncQuietly(async () => {
      await upsert("business_settings", settingsRow(settings));
      await upsert("barbers", barberRowsFromSettings(), true).catch(error => console.warn("Legado Supabase: nao foi possivel sincronizar barbeiros.", error.message));
    });
  };

  L.setAvailability = function setAvailability(value) {
    original.setAvailability(value);
    syncQuietly(() => upsert("availability", availabilityRow(value)));
  };

  L.setServices = function setServices(services) {
    const before = L.getServices(true).map(item => item.id);
    original.setServices(services);
    const after = L.getServices(true);
    const afterIds = new Set(after.map(item => item.id));
    syncQuietly(async () => {
      await upsert("services", after.map(serviceRow));
      await removeRows("services", before.filter(id => !afterIds.has(id)));
    });
  };

  L.setBlocks = function setBlocks(blocks) {
    const before = L.getBlocks().map(item => item.id);
    original.setBlocks(blocks);
    const after = L.getBlocks();
    const afterIds = new Set(after.map(item => item.id));
    syncQuietly(async () => {
      await upsert("blocked_slots", after.map(blockRow));
      await removeRows("blocked_slots", before.filter(id => !afterIds.has(id)), true);
    });
  };

  L.setPortfolio = function setPortfolio(items) {
    const before = L.getPortfolio(true).map(item => item.id);
    original.setPortfolio(items);
    const after = L.getPortfolio(true);
    const afterIds = new Set(after.map(item => item.id));
    syncQuietly(async () => {
      await upsertPortfolioRows(after);
      await removeRows("portfolio", before.filter(id => !afterIds.has(id)), true);
    });
  };

  L.setTestimonials = function setTestimonials(items) {
    const before = L.getTestimonials(true).map(item => item.id);
    original.setTestimonials(items);
    let after = L.getTestimonials(true);
    if (!accessToken()) after = after.filter(item => item.status === "pending" && item.active === false && item.source === "site");
    const afterIds = new Set(after.map(item => item.id));
    syncQuietly(async () => {
      await upsert("testimonials", after.map(testimonialRow), true);
      if (accessToken()) await removeRows("testimonials", before.filter(id => !afterIds.has(id)), true);
    });
  };

  L.setClients = function setClients(clients) {
    original.setClients(clients);
    if (!accessToken()) return;
    syncQuietly(() => upsert("clients", L.getClients().map(clientRow), true));
  };

  L.upsertClient = function upsertClient(client) {
    const saved = original.upsertClient(client);
    if (!accessToken()) return saved;
    syncQuietly(() => upsert("clients", clientRow(saved), true));
    return saved;
  };

  L.setProducts = function setProducts(products) {
    original.setProducts(products);
    if (!accessToken()) return;
    syncQuietly(() => upsert("products", L.getProducts(true).map(productRow), true));
  };

  L.upsertProduct = function upsertProduct(product) {
    const saved = original.upsertProduct(product);
    if (accessToken()) syncQuietly(() => upsert("products", productRow(saved), true));
    return saved;
  };

  L.setInventoryMovements = function setInventoryMovements(movements) {
    original.setInventoryMovements(movements);
    if (!accessToken()) return;
    syncQuietly(() => upsert("inventory_movements", L.getInventoryMovements().map(inventoryMovementRow), true));
  };

  L.upsertInventoryMovement = function upsertInventoryMovement(movement) {
    const saved = original.upsertInventoryMovement(movement);
    if (accessToken()) syncQuietly(() => upsert("inventory_movements", inventoryMovementRow(saved), true));
    return saved;
  };

  L.setProductSales = function setProductSales(sales) {
    original.setProductSales(sales);
    if (!accessToken()) return;
    syncQuietly(() => upsert("product_sales", L.getProductSales().map(productSaleRow), true));
  };

  L.upsertProductSale = function upsertProductSale(sale) {
    const saved = original.upsertProductSale(sale);
    if (accessToken()) syncQuietly(() => upsert("product_sales", productSaleRow(saved), true));
    return saved;
  };

  L.setCashRegisters = function setCashRegisters(registers) {
    original.setCashRegisters(registers);
    if (!accessToken()) return;
    syncQuietly(() => upsert("cash_registers", L.getCashRegisters(true).map(cashRegisterRow), true));
  };

  L.upsertCashRegister = function upsertCashRegister(register) {
    const saved = original.upsertCashRegister(register);
    if (accessToken()) syncQuietly(() => upsert("cash_registers", cashRegisterRow(saved), true));
    return saved;
  };

  L.setPayments = function setPayments(payments) {
    original.setPayments(payments);
    if (!accessToken()) return;
    syncQuietly(() => upsert("payments", L.getPayments(true).map(paymentRow), true));
  };

  L.upsertPayment = function upsertPayment(payment) {
    const saved = original.upsertPayment(payment);
    if (accessToken()) syncQuietly(() => upsert("payments", paymentRow(saved), true));
    return saved;
  };

  L.setCommissions = function setCommissions(commissions) {
    original.setCommissions(commissions);
    if (!accessToken()) return;
    syncQuietly(() => upsert("commissions", L.getCommissions(true).map(commissionRow), true));
  };

  L.upsertCommission = function upsertCommission(commission) {
    const saved = original.upsertCommission(commission);
    if (accessToken()) syncQuietly(() => upsert("commissions", commissionRow(saved), true));
    return saved;
  };

  L.setSettlements = function setSettlements(settlements) {
    original.setSettlements(settlements);
    if (!accessToken()) return;
    syncQuietly(() => upsert("barber_settlements", L.getSettlements(true).map(settlementRow), true));
  };

  L.upsertSettlement = function upsertSettlement(settlement) {
    const saved = original.upsertSettlement(settlement);
    if (accessToken()) syncQuietly(() => upsert("barber_settlements", settlementRow(saved), true));
    return saved;
  };

  L.saveClientProfile = async function saveClientProfile(client) {
    const normalized = L.normalizeClient(client);
    if (!normalized.phoneDigits || normalized.phoneDigits.length < 10) throw new Error("WhatsApp invalido para salvar o perfil.");
    const localDraft = original.upsertClient(normalized);
    const photo = await uploadClientPhoto(normalized);
    const savedRows = await request("rpc/save_client_profile", {
      method: "POST",
      body: JSON.stringify({
        p_client_name: normalized.name,
        p_client_phone: normalized.phone,
        p_phone_digits: normalized.phoneDigits,
        p_profile_photo: photo || normalized.photo || "",
        p_is_existing_customer: Boolean(normalized.existingCustomer),
        p_notes: normalized.notes || ""
      })
    });
    const savedClient = mapClient(savedRows?.[0] || localDraft, 0);
    original.upsertClient(savedClient);
    window.dispatchEvent(new CustomEvent("legado:datachange", { detail: { key: L.KEYS.clients, source: "profile" } }));
    return savedClient;
  };

  L.setBookings = function setBookings(bookings) {
    original.setBookings(bookings);
    syncQuietly(() => upsert("bookings", L.getBookings().map(bookingRow), true));
  };

  L.upsertBooking = function upsertBooking(booking) {
    const saved = original.upsertBooking(booking);
    syncQuietly(async () => { await upsert("bookings", bookingRow(saved), true); await upsert("clients", clientRow({ name: saved.name, phone: saved.phone, phoneDigits: saved.phoneDigits, photo: saved.clientPhoto }), true); });
    return saved;
  };

  L.upsertBookingOnline = async function upsertBookingOnline(booking) {
    const normalized = L.normalizeBooking(booking);
    const row = bookingRow(normalized);
    const rows = await upsert("bookings", row, true);
    const saved = mapBooking((rows || [])[0] || row);
    original.upsertBooking(saved);
    await upsert("clients", clientRow({ name: saved.name, phone: saved.phone, phoneDigits: saved.phoneDigits, photo: saved.clientPhoto }), true);
    return saved;
  };

  L.deleteBooking = function deleteBooking(id) {
    original.deleteBooking(id);
    syncQuietly(() => removeRows("bookings", id, true));
  };

  L.reserveBooking = function reserveBooking(booking) {
    const result = original.reserveBooking(booking);
    if (result.ok) syncQuietly(async () => { await upsert("bookings", bookingRow(result.booking), true); await upsert("clients", clientRow({ name: result.booking.name, phone: result.booking.phone, phoneDigits: result.booking.phoneDigits, photo: result.booking.clientPhoto }), true); });
    return result;
  };

  L.reserveBookingOnline = async function reserveBookingOnline(booking) {
    try {
      const draft = L.normalizeBooking({ ...booking, status: "confirmed" });
      const row = bookingRow(draft);
      const rows = await request("rpc/reserve_booking", {
        method: "POST",
        body: JSON.stringify({
          p_id: row.id,
          p_code: row.code,
          p_service_id: row.service_id,
          p_service_name: row.service_name,
          p_duration_minutes: row.duration_minutes,
          p_price_value: row.price_value,
          p_booking_date: row.booking_date,
          p_start_time: row.start_time,
          p_client_name: row.client_name,
          p_client_phone: row.client_phone,
          p_phone_digits: row.phone_digits,
          p_client_photo: row.client_photo,
          p_professional: row.professional,
          p_notes: row.notes,
          p_source: row.source
        })
      });
      const saved = mapBooking((rows || [])[0] || row);
      original.upsertBooking(saved);
      original.upsertClient({ name: saved.name, phone: saved.phone, phoneDigits: saved.phoneDigits, photo: saved.clientPhoto });
      return { ok: true, booking: saved };
    } catch (error) {
      if (/slot_conflict|not_available|bookings_no_active_overlap/i.test(String(error.message || ""))) {
        const remoteBookings = await fetchActiveBookingsForDate(booking.date).catch(() => []);
        const merged = new Map(L.getBookings().map(item => [String(item.id), item]));
        remoteBookings.forEach(item => merged.set(String(item.id), item));
        original.setBookings([...merged.values()]);
        return { ok: false, reason: "conflict", error };
      }
      throw error;
    }
  };

  L.lookupBookingOnline = async function lookupBookingOnline(phone, code) {
    const phoneDigits = L.normalizePhone(phone);
    const normalizedCode = String(code || "").trim().toUpperCase();
    if (!phoneDigits || !normalizedCode) return null;
    const rows = await request("rpc/lookup_booking", {
      method: "POST",
      body: JSON.stringify({ p_phone_digits: phoneDigits, p_code: normalizedCode })
    });
    const row = (rows || [])[0];
    if (!row) return null;
    const booking = mapBooking(row);
    original.upsertBooking(booking);
    if (booking.phoneDigits) original.upsertClient({ name: booking.name, phone: booking.phone, phoneDigits: booking.phoneDigits, photo: booking.clientPhoto });
    return booking;
  };

  L.cancelBookingOnline = async function cancelBookingOnline(booking, reason = "Cancelado pelo cliente") {
    const normalized = L.normalizeBooking(booking);
    const rows = await request("rpc/cancel_booking", {
      method: "POST",
      body: JSON.stringify({
        p_phone_digits: normalized.phoneDigits || L.normalizePhone(normalized.phone),
        p_code: normalized.code,
        p_reason: reason
      })
    });
    const row = (rows || [])[0];
    if (!row) throw new Error("Agendamento não encontrado para cancelamento.");
    const saved = mapBooking(row);
    original.upsertBooking(saved);
    return saved;
  };

  L.loadRemoteBookingsForDate = async function loadRemoteBookingsForDate(date, professional = "") {
    const remoteBookings = await fetchActiveBookingsForDate(date, professional);
    const merged = new Map(L.getBookings().map(item => [String(item.id), item]));
    remoteBookings.forEach(item => merged.set(String(item.id), item));
    original.setBookings([...merged.values()]);
    return remoteBookings;
  };

  L.submitTestimonialOnline = async function submitTestimonialOnline(testimonial) {
    const normalized = L.normalizeTestimonial(testimonial);
    await upsertMinimal("testimonials", testimonialRow(normalized), true);
    const saved = normalized;
    const current = L.getTestimonials(true).filter(item => String(item.id) !== String(saved.id));
    original.setTestimonials([...current, saved]);
    if (saved.phoneDigits) original.upsertClient({ name: saved.name, phone: saved.phone, phoneDigits: saved.phoneDigits, photo: saved.photo });
    return saved;
  };

  L.confirmBooking = function confirmBooking(id, options = {}) {
    const result = original.confirmBooking(id, options);
    if (result.ok) {
      syncQuietly(async () => {
        await upsert("bookings", bookingRow(result.booking), true);
        if (result.cancelledConflicts?.length) {
          const current = L.getBookings().filter(item => result.cancelledConflicts.some(conflict => String(conflict.id) === String(item.id)));
          await upsert("bookings", current.map(bookingRow), true);
        }
      });
    }
    return result;
  };

  L.restoreBackup = function restoreBackup(data) {
    original.restoreBackup(data);
    syncQuietly(async () => {
      await upsert("business_settings", settingsRow(L.getSettings()));
      await upsert("availability", availabilityRow(L.getAvailability()));
      await upsert("services", L.getServices(true).map(serviceRow));
      await upsert("blocked_slots", L.getBlocks().map(blockRow));
      await upsert("bookings", L.getBookings().map(bookingRow), true);
      await upsert("clients", L.getClients().map(clientRow), true);
      await upsertPortfolioRows(L.getPortfolio(true));
      if (L.getProducts) await upsert("products", L.getProducts(true).map(productRow), true).catch(error => console.warn("Legado Supabase:", error.message));
      await upsert("barbers", barberRowsFromSettings(), true).catch(error => console.warn("Legado Supabase:", error.message));
      if (L.getInventoryMovements) await upsert("inventory_movements", L.getInventoryMovements().map(inventoryMovementRow), true).catch(error => console.warn("Legado Supabase:", error.message));
      if (L.getProductSales) await upsert("product_sales", L.getProductSales().map(productSaleRow), true).catch(error => console.warn("Legado Supabase:", error.message));
      if (L.getPayments) await upsert("payments", L.getPayments(true).map(paymentRow), true).catch(error => console.warn("Legado Supabase:", error.message));
      if (L.getCashRegisters) await upsert("cash_registers", L.getCashRegisters(true).map(cashRegisterRow), true).catch(error => console.warn("Legado Supabase:", error.message));
      if (L.getCommissions) await upsert("commissions", L.getCommissions(true).map(commissionRow), true).catch(error => console.warn("Legado Supabase:", error.message));
      if (L.getSettlements) await upsert("barber_settlements", L.getSettlements(true).map(settlementRow), true).catch(error => console.warn("Legado Supabase:", error.message));
      await upsert("testimonials", L.getTestimonials(true).map(testimonialRow), true);
    });
  };

  window.LegadoSupabase = { hydrateFromSupabase, signIn, signOut, accessToken, refreshToken, getCurrentUser, getAdminProfile, hasAdminSession, createBarberAccess, stableUuid };
  hydrateFromSupabase().catch(error => console.warn("Legado Supabase:", error.message));
})();
