"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewChatMessage = exports.razorpayWebhook = exports.dailyBrokerReminders = exports.onPropertyModerated = exports.onPropertyCreated = exports.onEscrowUpdated = exports.onOfferUpdated = exports.onOfferCreated = void 0;
const admin = require("firebase-admin");
const functions = require("firebase-functions");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// ── Helper: send FCM + in-app notification ────────────────────────────────
async function notifyUser(userId, title, body, data = {}) {
    var _a;
    if (!userId)
        return;
    const tokensSnap = await db
        .collection("users").doc(userId)
        .collection("fcmTokens").where("enabled", "==", true).get();
    await db.collection("notifications").add({
        userId, title, message: body,
        channel: "firebase", type: (_a = data.type) !== null && _a !== void 0 ? _a : "general",
        metadata: data, read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (tokensSnap.empty)
        return;
    const tokens = tokensSnap.docs.map((d) => d.id);
    const result = await messaging.sendEachForMulticast({
        tokens,
        notification: { title, body },
        data,
        android: { priority: "high", notification: { channelId: "estatex_default", priority: "high" } },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
    const invalid = result.responses
        .map((r, i) => { var _a, _b; return (!r.success && ((_b = (_a = r.error) === null || _a === void 0 ? void 0 : _a.code) === null || _b === void 0 ? void 0 : _b.includes("registration-token"))) ? tokens[i] : null; })
        .filter(Boolean);
    if (invalid.length > 0) {
        const batch = db.batch();
        invalid.forEach((t) => batch.update(db.collection("users").doc(userId).collection("fcmTokens").doc(t), { enabled: false }));
        await batch.commit();
    }
}
function fmt(amount) {
    if (amount >= 10000000)
        return `₹${(amount / 10000000).toFixed(2)} Cr`;
    if (amount >= 100000)
        return `₹${(amount / 100000).toFixed(1)} L`;
    return `₹${amount.toLocaleString("en-IN")}`;
}
async function collectFee(dealId, dealValue) {
    const snap = await db.collection("platform_fees").where("dealId", "==", dealId).limit(1).get();
    const fee = Math.round(dealValue * 0.015);
    if (snap.empty) {
        await db.collection("platform_fees").add({
            dealId, amount: fee, feePercent: 1.5, dealValue,
            status: "collected",
            collectedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    else {
        await snap.docs[0].ref.update({
            status: "collected",
            collectedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
}
// ── 1. Offer created ──────────────────────────────────────────────────────
exports.onOfferCreated = functions.firestore
    .document("offers/{offerId}")
    .onCreate(async (snap) => {
    var _a, _b, _c, _d, _e;
    const d = snap.data();
    let title = "your property";
    if (d.propertyId) {
        const p = await db.collection("properties").doc(d.propertyId).get();
        if (p.exists)
            title = `"${(_b = (_a = p.data()) === null || _a === void 0 ? void 0 : _a.title) !== null && _b !== void 0 ? _b : "your property"}"`;
    }
    await notifyUser((_c = d.sellerId) !== null && _c !== void 0 ? _c : "", "New offer received 🏷️", `A buyer offered ${fmt((_d = d.amount) !== null && _d !== void 0 ? _d : 0)} for ${title}. Review and respond.`, { type: "offer_received", offerId: snap.id, propertyId: (_e = d.propertyId) !== null && _e !== void 0 ? _e : "" });
});
// ── 2. Offer status changed ───────────────────────────────────────────────
exports.onOfferUpdated = functions.firestore
    .document("offers/{offerId}")
    .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status)
        return;
    const { buyerId = "", sellerId = "", amount = 0, status = "" } = after;
    const offerId = change.after.id;
    const a = fmt(amount);
    if (status === "accepted") {
        await notifyUser(buyerId, "Offer accepted! 🎉", `Your offer of ${a} was accepted. Pay the token amount to lock the deal.`, { type: "offer_accepted", offerId, amount: String(amount) });
    }
    else if (status === "rejected") {
        await notifyUser(buyerId, "Offer not accepted", `Your offer of ${a} was not accepted. You can explore other properties.`, { type: "offer_rejected", offerId });
    }
    else if (status === "counter") {
        await notifyUser(buyerId, "Counter offer received ↩️", `The seller has countered with ${a}. Review and decide.`, { type: "counter_offer", offerId, amount: String(amount) });
    }
    else if (status === "completed") {
        await Promise.all([
            notifyUser(buyerId, "Deal completed! 🏡", `Congratulations! Your deal for ${a} is complete.`, { type: "deal_completed", offerId }),
            notifyUser(sellerId, "Deal completed! 🏡", `Your property deal for ${a} is complete.`, { type: "deal_completed", offerId }),
        ]);
        await collectFee(offerId, amount);
    }
});
// ── 3. Escrow status changed ──────────────────────────────────────────────
exports.onEscrowUpdated = functions.firestore
    .document("escrow/{escrowId}")
    .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status)
        return;
    const { brokerId = "", buyerId = "", amount = 0, dealId = "" } = after;
    const escrowId = change.after.id;
    if (after.status === "completed") {
        await Promise.all([
            notifyUser(brokerId, "Escrow funds released 💰", `${fmt(amount)} has been released to you. Deal complete!`, { type: "escrow_released", escrowId, dealId }),
            notifyUser(buyerId, "Deal finalised", `Your token of ${fmt(amount)} has been released to the seller.`, { type: "escrow_released", escrowId, dealId }),
        ]);
    }
    else if (after.status === "cancelled") {
        await notifyUser(buyerId, "Escrow refunded", `Your payment of ${fmt(amount)} has been refunded.`, { type: "escrow_refunded", escrowId, dealId });
    }
});
// ── 4. Property submitted for review ─────────────────────────────────────
exports.onPropertyCreated = functions.firestore
    .document("properties/{propertyId}")
    .onCreate(async (snap) => {
    var _a, _b, _c, _d, _e;
    const d = snap.data();
    await db.collection("admin_notifications").add({
        type: "property_pending_review", propertyId: snap.id,
        title: (_a = d.title) !== null && _a !== void 0 ? _a : "", city: (_b = d.city) !== null && _b !== void 0 ? _b : "",
        uploadedBy: (_c = d.uploadedBy) !== null && _c !== void 0 ? _c : "", status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await notifyUser((_d = d.uploadedBy) !== null && _d !== void 0 ? _d : "", "Property submitted ✅", `"${(_e = d.title) !== null && _e !== void 0 ? _e : "Your property"}" was submitted for review. We'll notify you once verified.`, { type: "property_submitted", propertyId: snap.id });
});
// ── 5. Property approved or rejected ─────────────────────────────────────
exports.onPropertyModerated = functions.firestore
    .document("properties/{propertyId}")
    .onUpdate(async (change) => {
    var _a, _b, _c, _d;
    const before = change.before.data();
    const after = change.after.data();
    if (before.verificationStatus === after.verificationStatus)
        return;
    const uid = (_b = (_a = after.uploadedBy) !== null && _a !== void 0 ? _a : after.createdBy) !== null && _b !== void 0 ? _b : "";
    const title = (_c = after.title) !== null && _c !== void 0 ? _c : "Your property";
    const propertyId = change.after.id;
    if (after.verificationStatus === "approved") {
        await notifyUser(uid, "Property live! ✅", `"${title}" is now live on EstateX and visible to buyers.`, { type: "property_approved", propertyId });
    }
    else if (after.verificationStatus === "rejected") {
        const reason = (_d = after.rejectionReason) !== null && _d !== void 0 ? _d : "Please review and resubmit.";
        await notifyUser(uid, "Property needs changes", `"${title}" needs updates before going live. Reason: ${reason}`, { type: "property_rejected", propertyId });
    }
});
// ── 6. Daily broker follow-up reminders (9 AM IST) ───────────────────────
exports.dailyBrokerReminders = functions.pubsub
    .schedule("30 3 * * *").timeZone("Asia/Kolkata")
    .onRun(async () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const snap = await db.collection("leads")
        .where("followUpDate", "<=", admin.firestore.Timestamp.fromDate(tomorrow))
        .where("status", "!=", "closed").get();
    const map = {};
    snap.docs.forEach((d) => {
        var _a;
        const bid = d.data().brokerId;
        if (bid)
            map[bid] = ((_a = map[bid]) !== null && _a !== void 0 ? _a : 0) + 1;
    });
    await Promise.all(Object.entries(map).map(([brokerId, count]) => notifyUser(brokerId, "Follow-up reminder 📅", count === 1 ? "You have a lead to follow up with today."
        : `You have ${count} leads to follow up with today.`, { type: "broker_reminder", count: String(count) })));
    functions.logger.info(`Reminders sent to ${Object.keys(map).length} brokers`);
});
// ── 7. Razorpay webhook ───────────────────────────────────────────────────
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const crypto = await Promise.resolve().then(() => require("crypto"));
    const secret = (_b = (_a = functions.config().razorpay) === null || _a === void 0 ? void 0 : _a.webhook_secret) !== null && _b !== void 0 ? _b : "";
    const sig = req.headers["x-razorpay-signature"];
    if (secret && sig) {
        const expected = crypto.createHmac("sha256", secret)
            .update(JSON.stringify(req.body)).digest("hex");
        if (expected !== sig) {
            res.status(400).send("Invalid signature");
            return;
        }
    }
    const event = req.body.event;
    const payment = (_d = (_c = req.body.payload) === null || _c === void 0 ? void 0 : _c.payment) === null || _d === void 0 ? void 0 : _d.entity;
    if (event === "payment.captured" && payment) {
        const { id: paymentId = "", order_id: orderId = "", notes = {}, amount: paise = 0 } = payment;
        const dealId = (_e = notes.dealId) !== null && _e !== void 0 ? _e : "";
        if (dealId) {
            const batch = db.batch();
            const escSnap = await db.collection("escrow").where("dealId", "==", dealId).limit(1).get();
            if (!escSnap.empty) {
                batch.update(escSnap.docs[0].ref, {
                    paymentStatus: "captured", transactionId: paymentId, razorpayOrderId: orderId,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            batch.set(db.collection("payments").doc(paymentId), {
                dealId, paymentId, orderId, amount: paise / 100,
                status: "captured", gateway: "razorpay",
                capturedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            await batch.commit();
        }
    }
    else if (event === "payment.failed" && payment) {
        const dealId = (_g = (_f = payment.notes) === null || _f === void 0 ? void 0 : _f.dealId) !== null && _g !== void 0 ? _g : "";
        if (dealId) {
            const escSnap = await db.collection("escrow").where("dealId", "==", dealId).limit(1).get();
            if (!escSnap.empty) {
                await escSnap.docs[0].ref.update({
                    paymentStatus: "failed",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            const offerSnap = await db.collection("offers").doc(dealId).get();
            const buyerId = (_j = (_h = offerSnap.data()) === null || _h === void 0 ? void 0 : _h.buyerId) !== null && _j !== void 0 ? _j : "";
            if (buyerId) {
                await notifyUser(buyerId, "Payment failed", "Your token payment could not be processed. Please try again.", { type: "payment_failed", dealId });
            }
        }
    }
    res.status(200).send("OK");
});
// ── 8. New chat message push notification ────────────────────────────────
exports.onNewChatMessage = functions.firestore
    .document("chat_rooms/{chatRoomId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
    var _a, _b;
    const d = snap.data();
    const chatRoomId = context.params.chatRoomId;
    const room = (await db.collection("chat_rooms").doc(chatRoomId).get()).data();
    if (!room)
        return;
    const recipientId = d.senderId === room.buyerId ? room.brokerId : room.buyerId;
    if (!recipientId)
        return;
    await notifyUser(recipientId, "New message 💬", `New message about ${(_a = room.propertyTitle) !== null && _a !== void 0 ? _a : "a property"}`, { type: "new_message", chatRoomId, propertyTitle: (_b = room.propertyTitle) !== null && _b !== void 0 ? _b : "" });
});
//# sourceMappingURL=index.js.map