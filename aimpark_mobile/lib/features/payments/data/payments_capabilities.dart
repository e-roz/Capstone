/// Whether the server can open one checkout for every unpaid bill at once.
///
/// **On.** The server now has `POST /api/payments/checkout-all`. This stays a
/// switch rather than being deleted so it can be turned off in one place if the
/// endpoint ever has to be pulled.
///
/// ### The contract the server meets
///
/// `POST /api/payments/checkout-all`, authenticated as the payer, no body.
///
/// * Collects every bill of the caller's that is **payable** — Pending, amount
///   above zero, and not already Processing — and totals them. The *server*
///   decides; the phone sends neither a list nor an amount.
/// * Opens **one** provider checkout (PayMongo, or the simulator) for that total,
///   with one line item per bill, and marks those bills Processing against it.
/// * Responds with the same shape as a single checkout —
///   `{ paymentId, checkoutUrl, provider, amountDue }` — where `paymentId` is the
///   first bill, `amountDue` is the **total**, and `paymentIds: [...]` lists them
///   all.
/// * When the provider confirms payment, **every** bill in it becomes Paid in one
///   step, with a single "Payment received" notification.
/// * 409 with a plain message when nothing is payable, **including** a second tap
///   while a Pay all is already open: those bills are Processing by then, and a
///   provider's link cannot be rebuilt afterwards.
const bool kPayAllAvailable = true;
