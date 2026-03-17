(function () {
    const itemRegex = /(?:^|[\?&\/])item=(\d+)/i;
    /** @type {Map<string, string>} itemId -> tier */
    const itemToTier = new Map();

    // --- Overall BiS: tab #tab-bis-items-overall-bis OR table (.markup-table-wrapper table.grid) ---
    const tab = document.getElementById("tab-bis-items-overall-bis");
    if (tab) {
        const links = tab.querySelectorAll('a[data-type="item"][href*="item="], a[href*="item="][data-game="wow"]');
        links.forEach((a) => {
            const m = (a.getAttribute("href") || "").match(itemRegex);
            if (m) itemToTier.set(m[1], "BiS");
        });
    }
    if (itemToTier.size === 0) {
        // Alternative: Season BiS table (Slot | Enchant | Item | Source) — Item column = 3rd cell
        const table = document.querySelector(".markup-table-wrapper table.grid, .markup-table-wrapper table");
        if (table && table.tBodies.length) {
            table.tBodies[0].querySelectorAll("tr").forEach((tr) => {
                const itemCell = tr.querySelector("td:nth-child(3)");
                if (!itemCell) return;
                itemCell.querySelectorAll('a[href*="item="]').forEach((a) => {
                    const m = (a.getAttribute("href") || "").match(itemRegex);
                    if (m) itemToTier.set(m[1], "BiS");
                });
            });
        }
    }
    if (itemToTier.size === 0) {
        console.warn("No BiS items found. Open the Overall BiS tab or a Season BiS table.");
    }

    // --- Trinket Tier List: #trinket-tier-list section OR .wh-wrapper > .tier-list-rows (same structure) ---

    function processTierListRows(rowsEl) {
        if (!rowsEl) return;
        rowsEl.querySelectorAll(".tier-list-tier").forEach((tierBlock) => {
            const labelEl = tierBlock.querySelector(".tier-label");
            const tierLabel = (labelEl && labelEl.textContent ? labelEl.textContent.trim() : "")[0];
            const luaTier = tierLabel;
            if (!luaTier) return;
            const content = tierBlock.querySelector(".tier-content");
            if (!content) return;
            content.querySelectorAll('a[href*="item="]').forEach((a) => {
                const m = (a.getAttribute("href") || "").match(itemRegex);
                if (m && !itemToTier.has(m[1])) itemToTier.set(m[1], luaTier);
            });
        });
    }

    const trinketHeading = document.getElementById("trinket-tier-list");
    let tierRows = null;
    if (trinketHeading) {
        const container = trinketHeading.closest(".wh-center");
        tierRows = container ? container.querySelector(".tier-list-rows") : null;
    }
    if (!tierRows) {
        // Alternative layout: .wh-wrapper > .tier-list-rows (no #trinket-tier-list heading)
        const first = document.querySelector(".wh-wrapper .tier-list-rows");
        if (first && first.querySelector(".tier-list-tier")) tierRows = first;
    }
    processTierListRows(tierRows);

    const lines = Array.from(itemToTier.entries())
        .sort((a, b) => Number(a[0]) - Number(b[0]))
        .map(([itemId, tier]) => `    [${itemId}] = "${tier}",`);

    const lua = lines.length ? `{\n${lines.join("\n")}\n}` : `{}`;

    return lua;
})();
