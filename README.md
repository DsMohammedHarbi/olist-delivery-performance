# Olist Delivery Performance — Power BI Dashboard

An operations analysis of ~96,000 delivered orders from Olist, a Brazilian e-commerce marketplace.
The goal: find out **how often orders arrive late, why, and what it costs in customer satisfaction**, and turn that into actions an operations team can take.

![Overview page](images/overview.png)

---

## Business questions

1. How many orders arrive later than the date promised to the customer?
2. Does a late delivery hurt the customer's rating?
3. Where does the delay happen — with the seller, or in shipping?
4. Which states and which months are hit hardest?
5. Which sellers slow orders down?

## Key findings

1. **8.1% of delivered orders arrive late** (about 8K of 96K orders).
2. **Late orders lose almost 2 stars.** They are rated 2.6 / 5, compared with 4.3 / 5 for on-time orders.
3. **Shipping causes most of the delay.** Late orders spend 25.2 days in shipping vs 7.4 for on-time orders, while time with the seller only rises from 2.1 to 4.8 days.
4. **Northeast states see the most delays** — CE (15.4%) and BA (14.0%) — and RJ combines a 13.5% late rate with one of the largest order volumes.
5. **Cross-state orders are late about 50% more often** than orders where the seller and customer are in the same state (9.3% vs 6.1%).
6. **Delays spike in peak seasons:** around 14% in November 2017 (Black Friday) and over 20% in March 2018.
7. **Orders held by the seller for 11+ days are late 38% of the time**, compared with under 6% for orders shipped within a day.

## Recommendations

- **Add carrier capacity before peak seasons**, especially November.
- **Review carriers serving the Northeast and RJ**, and consider fulfilment closer to those customers, since cross-state orders are late more often.
- **Set a maximum prep time for sellers** and follow up with sellers who regularly exceed it.

---

## Dashboard pages

| Page | What it shows |
|---|---|
| **Overview** | Headline KPIs, the rating gap between late and on-time orders, the seller vs shipping breakdown, and a summary of findings |
| **Where & When** | Late rate by customer state, same-state vs cross-state orders, and the monthly trend of orders and late rate |
| **Sellers** | A seller scorecard (sellers with 50+ orders) and late rate by seller prep time |

All pages share synced date and state filters, and include navigation buttons in the header.

![Where & When page](images/where_when.png)
![Sellers page](images/sellers.png)

## How it was built

### Data preparation — Power Query
- Loaded five tables: `orders`, `order_items`, `customers`, `sellers`, `reviews`.
- Kept **delivered orders only**, and removed delivered orders with no delivery date.
- Added three columns:
  - `Prep Days` — payment approval → order handed to the carrier (time with the seller)
  - `Shipping Days` — carrier → customer
  - `Is Late` — 1 if delivered after the estimated delivery date, otherwise 0
- **Data quality issue:** around 1,350 orders have a carrier date *before* payment approval, which is impossible. For these orders, the negative prep time was set to blank instead of deleting the order, so they still count toward the late rate but don't distort average prep time.
- Replaced the anonymised seller IDs with readable labels (`Seller 0001`, `Seller 0002`, …).

### Data model
- Star schema with `orders` as the fact table, linked to `customers`, `sellers` (through `order_items`) and `reviews`.
- Single-direction filtering by default. The `orders`–`order_items` relationship filters both ways, so seller filters reach order-level measures.

### DAX
- **Measures:** `Total Orders`, `Late Orders`, `Late %`, `Avg Prep Days`, `Avg Shipping Days`, `Avg Review Score`.
- The rating measure averages **per order**, because some orders have more than one review and the reviews table also includes orders that were never delivered:

```DAX
Avg Review Score = AVERAGEX(orders, CALCULATE(AVERAGE(reviews[review_score])))
```

- **Calculated columns:** `Delivery Status` (Late / On Time), `Purchase Month`, `Seller State` and `Route` (same-state vs cross-state), and `Prep Bucket` with a sort-order column so the buckets display in the right order.

### Design
- Custom theme and a fixed 1280×720 layout grid with consistent spacing.
- One colour per meaning: red for late / bad, blue for normal values, grey for context.
- Chart titles state the finding (e.g. *"Shipping causes most of the delay"*), not just the metric.
- Small groups are filtered out so percentages stay reliable: states with fewer than 1,000 orders and sellers with fewer than 50 orders.

## Repository

```
├── olist_operations.pbix     Power BI report
├── olist_operations.pdf      PDF export of the dashboard
├── olist_theme.json          Custom report theme
└── images/                   Dashboard screenshots
```

## Data

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle.
Analysis period: January 2017 – August 2018. The raw CSV files are not included; download them from Kaggle to refresh the report.

## Tools

Power BI Desktop — Power Query and DAX

---

**Mohammed Alharbi** — Data Analyst · [LinkedIn](https://linkedin.com/in/mohammed-alharbi-data) · [Portfolio](https://dsmohammedharbi.github.io)
