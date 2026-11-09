# Owner's Original Plan (received 2026-11-08)

> Kept as received, for reference. Where this differs from the other docs, **DECISIONS.md wins** (e.g. Supabase replaces the FastAPI backend; property status is split into publish state + availability).

```text
LAND SELLING PLATFORM — COMPLETE IMPLEMENTATION PLAN

PROJECT OVERVIEW
Build a premium direct-to-customer land selling platform for our company.
This is NOT an OLX-style marketplace.
There must NOT be any third-party sellers, external property owners, brokers, or agents listing their properties on the platform.
Only our company/admin can add and manage land properties.
The platform has two major parts:
1. Customer-facing website
2. Secure Admin Panel
The customer website allows customers to discover our available land properties, view complete property information, submit enquiries, schedule site visits, and eventually proceed with purchasing.
The Admin Panel gives our authorized administrators complete control over properties, website content, assets, customer enquiries, site visits, bookings, and other platform operations.

CORE BUSINESS MODEL
Our Company → Admin Panel → Our Land Properties → Customer Website → Customer discovers property
→ Customer views property details → Customer submits enquiry / schedules site visit → Sales team handles customer
→ Booking / Purchase → Property becomes Sold

CUSTOMERS MUST NOT BE ABLE TO:
* Add their own land * Sell their own land * Create property listings * Become sellers * Become agents * Publish third-party properties
The platform is completely controlled by our company.

Before writing production code, understand and define the complete system. Define:
* Website name and branding * Target locations * Property categories * Supported area units * Pricing structure
* Property status workflow * Customer enquiry workflow * Site visit workflow * Booking workflow * Purchase workflow
* Admin permissions * Legal/document requirements * Contact methods * Payment requirements

Initial property categories may include:
* Residential Plots * Agricultural Land * Commercial Land * Industrial Land * Farm Land * Villa Plots
Do not add unnecessary categories if the business does not require them.

Recommended architecture:
Customer Website → Backend API → PostgreSQL / Object Storage / Authentication / Admin Panel
Admin Panel → Backend API → PostgreSQL / Object Storage

Design the complete customer experience before implementing functionality. The design must feel:
* Premium * Professional * Trustworthy * Modern * Real-estate focused * Clean * Easy to navigate * Mobile responsive
Do NOT simply copy OLX. The website should feel like a premium land-selling company's official digital platform.

CUSTOMER WEBSITE PAGES:
1. Home 2. Explore Properties 3. Property Details 4. About Us 5. Locations 6. Contact 7. FAQ 8. Customer Login/Register
9. Saved Properties 10. Customer Dashboard 11. Enquiry history 12. Site visits 13. Terms and Policies

HOMEPAGE SHOULD INCLUDE:
* Premium hero section * Strong land-focused headline * Search functionality * Featured properties * Recently added properties
* Popular locations * Why choose us * Property verification/trust section * How the buying process works
* Customer testimonials * FAQ * Contact CTA * Footer
The UI should prioritize property discovery and conversion.

Design a proper relational PostgreSQL database. Core entities should include:
Users, Admins, Properties, Property Images, Property Videos, Property Documents, Locations, Amenities, Nearby Places,
Enquiries, Site Visits, Bookings, Favorites/Wishlist, Notifications, Website Content, Website Assets, Audit Logs

PROPERTY DATA SHOULD SUPPORT:
* Property ID * Property title * Property type * Description * State * District * City * Area/locality * Full address
* Latitude * Longitude * Total area * Area unit * Length * Width * Price * Price unit/type * Road width * Facing
* Water availability * Electricity availability * Approval information * Legal/document information * Nearby facilities
* Highlights * Property status * Created date * Updated date * Published date

PROPERTY STATUS SHOULD SUPPORT:
* Draft * Published * Available * Reserved * Sold * Hidden * Archived
Design proper relationships and indexes. Use database constraints and validation wherever appropriate.

Create a secure Admin Panel. Admin login must be separate from normal customer functionality.
Admin should be able to securely authenticate and access administrative features.
Initial admin role: SUPER ADMIN / ADMIN
Future roles may include: * Super Admin * Property Manager * Sales Manager * Content Manager
But do not overcomplicate the first version.

ADMIN DASHBOARD SHOULD SHOW:
* Total properties * Available properties * Reserved properties * Sold properties * Draft properties
* New enquiries * Pending site visits * Recent activities
Provide useful summary cards and recent activity information.

Admin must have complete CRUD control over properties. ADMIN CAN:
* Add property * Edit property * View property * Publish property * Unpublish property * Hide property * Archive property
* Delete/archive property * Change price * Update property information * Change property status
* Mark property Reserved * Mark property Sold

CREATE PROPERTY FORM SHOULD INCLUDE:
Basic Information: * Property title * Property type * Description
Location: * State * District * City * Locality * Address * Latitude * Longitude
Property Size: * Area * Unit * Length * Width * Dimensions
Pricing: * Price * Price unit * Negotiable or not
Property Details: * Facing * Road width * Water availability * Electricity * Approval status * Other relevant details
Highlights: * Key selling points * Nearby facilities * Additional information
Media: * Images * Videos * Documents
Status: * Draft * Published * Available * Reserved * Sold * Hidden * Archived

Admin must have complete control over property assets.
PROPERTY IMAGES: Admin can: * Upload images * Delete images * Reorder images * Set cover image * Replace images
PROPERTY VIDEOS: Admin can: * Add video * Upload video if supported * Remove video * Set primary video
PROPERTY DOCUMENTS: Admin can manage: * Property documents * Approval documents * Brochures * Layout plans * Other relevant files
Validate uploaded files. Do not expose private documents publicly unless explicitly intended.

Build the customer-facing property listing page. Customers should be able to:
* Browse properties * Search properties * Filter properties * Sort properties * Open property details
PROPERTY CARD SHOULD SHOW:
* Cover image * Property title * Location * Area * Price * Property type * Key highlight * Availability status * View Details button
Use clean, premium property cards.

Implement powerful property discovery.
SEARCH BY: * Location * City * Area/locality * Property name * Property type
FILTER BY: * Property type * Location * Price range * Area range * Area unit * Road width * Facing * Availability * Amenities * Approval status
SORT BY: * Newest * Price low to high * Price high to low * Area low to high * Area high to low * Featured/recommended
Filtering should be fast and scalable.

This is one of the most important pages. The property details page should provide all important information in a structured manner. Include:
* Image gallery * Cover image * Property video * Property title * Location * Price * Area * Dimensions * Property type
* Road width * Facing * Water * Electricity * Approval information * Property highlights * Description * Nearby facilities
* Map * Relevant document information * Enquiry CTA * Contact CTA * Schedule Site Visit CTA * Save Property CTA
Example structure:
PROPERTY MEDIA / PROPERTY TITLE / LOCATION / PRICE / PROPERTY OVERVIEW / PROPERTY HIGHLIGHTS / DESCRIPTION / AMENITIES
LOCATION MAP / NEARBY PLACES / DOCUMENT/LEGAL INFORMATION / CONTACT / ENQUIRY / SCHEDULE SITE VISIT / RELATED PROPERTIES

Every property should support geographical location. Admin should be able to provide: * Latitude * Longitude * Address
Admin may select the location through a map interface. Customer should see the property location on a map.
Potential future functionality: * Nearby schools * Nearby hospitals * Roads * Railway stations * Airports * Important landmarks
Do not expose sensitive/private location information unless intended by the business.

Customers should be able to submit enquiries for properties.
ENQUIRY FORM: * Name * Phone number * Email * Property * Message * Preferred contact method
After submission: * Store enquiry * Show confirmation to customer * Notify admin * Associate enquiry with property * Associate enquiry with customer if logged in
ADMIN SHOULD SEE: * Customer name * Contact details * Property * Message * Created date * Enquiry status
ENQUIRY STATUS: * New * Contacted * Follow-up * Interested * Not Interested * Converted * Closed
Admin should be able to update the status.

Allow customers to request a property site visit.
CUSTOMER CAN SELECT: * Property * Date * Preferred time * Number of visitors * Contact details * Optional message
SITE VISIT STATUS: * Requested * Confirmed * Rescheduled * Completed * Cancelled
ADMIN CAN: * View requests * Confirm visit * Reschedule * Cancel * Mark completed * Add notes
Customer should receive confirmation after admin action.

Initially, customers may browse properties without creating an account. Later implement customer accounts.
CUSTOMER ACCOUNT SHOULD INCLUDE: * Profile * Saved properties * Enquiries * Site visits * Recently viewed properties * Notifications
Authentication must be secure.

Allow customers to save properties. Customer can: * Save property * Remove property * View saved properties
Customer dashboard should contain: MY SAVED PROPERTIES
This is useful because customers may compare multiple properties before making a decision.

Allow customers to compare selected properties. Comparison should show:
* Property type * Area * Price * Road width * Facing * Water * Electricity * Approval * Distance/location * Other relevant attributes
Example: Property A vs Property B vs Property C. Make comparison easy to understand.

Implement booking only after enquiry and site visit systems are stable. Expected flow:
Property → Enquiry → Customer Contact → Site Visit → Customer Decision → Booking Request → Admin Approval
→ Property Reserved → Documentation → Purchase → Property Sold
BOOKING STATUS: * Requested * Pending Approval * Approved * Payment Pending * Reserved * Cancelled * Completed
Admin should control the booking state. When approved: Property status becomes RESERVED.
When the transaction is completed: Property status becomes SOLD.

Do not make complete property payments the first implementation priority.
Initially, customers can contact the sales team and complete the transaction through the company's established process.
Later implement online payments if required.
Potential payment functionality: * Booking amount * Payment gateway * Payment status * Transaction ID * Receipts * Payment history * Refund status
Possible payment statuses: * Pending * Successful * Failed * Refunded * Cancelled
Payment implementation must be designed carefully according to the company's legal, accounting, and business requirements.

Admin should eventually be able to control website content without requiring code changes. ADMIN CAN MANAGE:
Homepage: * Hero title * Hero description * Hero image/video * Featured properties * Promotional sections
About page: * Company description * Images * Mission * Vision * Values
FAQ: * Add FAQ * Edit FAQ * Delete FAQ * Reorder FAQ
Locations: * Add location * Edit location * Remove location
Testimonials: * Add * Edit * Remove
Website banners: * Add * Remove * Replace * Reorder
This makes the Admin Panel a proper CMS as well as a Property Management System.

CUSTOMER NOTIFICATIONS:
* Enquiry received * Enquiry response * Site visit confirmation * Site visit reschedule * Site visit reminder * Booking update * Property status update
ADMIN NOTIFICATIONS:
* New enquiry * New site visit * New customer * Booking request * Payment notification
Start with in-app/email notifications if required. Push notifications can be added later.

The website must be SEO-friendly. Every property should have a clean URL.
Example: /land/25-cent-residential-plot-visakhapatnam
Each property should have: * SEO title * Meta description * Canonical URL * Open Graph image * Structured data where appropriate
Also implement: * Sitemap * Robots.txt * Proper heading hierarchy * Image alt text * Fast loading * Mobile optimization
Create location-focused pages where useful. Example: /plots-for-sale/visakhapatnam

Admin should eventually be able to see:
* Property views * Unique visitors * Enquiries * Site visits * Saved properties * Booking requests * Conversion rate * Sold properties
Property-level analytics: Property Views, Enquiries, Site Visits, Bookings, Sales
This helps identify high-performing properties.

Track important admin activities. Examples:
* Property created * Property updated * Property deleted/archived * Price changed * Property published * Property unpublished
* Property marked reserved * Property marked sold * Asset uploaded * Asset deleted * Enquiry status changed * Booking status changed
Store: * Admin * Action * Entity * Timestamp * Relevant details
This improves accountability and debugging.

Security is critical because the Admin Panel controls the entire platform. Implement:
* Secure authentication * Password hashing * Session/token security * Authorization * Role-based access control
* API authorization * Input validation * File upload validation * File size limits * File type validation * Rate limiting
* CSRF protection where applicable * XSS protection * SQL injection prevention * Secure headers * HTTPS
* Secure environment variables * Database backups * Audit logs
Never expose admin-only APIs to customers. Never trust frontend authorization alone.
Every protected backend endpoint must validate permissions.

The platform must work properly on: * Desktop * Laptop * Tablet * Mobile
Customer website should be mobile-first.
Admin Panel should also be responsive, but desktop can receive priority for complex management screens.
Test: * Small mobile * Standard Android * iPhone-sized screens * Tablet * Laptop * Large desktop

Optimize: * Image loading * Image sizes * Lazy loading * Video loading * Database queries * API response time
* Pagination * Search * Filtering * Caching * Static assets
Property listings should use pagination or infinite scrolling. Do not load every property and every image at once.
Use optimized thumbnails for property cards.

Perform complete end-to-end testing.
CUSTOMER TESTING:
* Homepage * Navigation * Property listing * Search * Filters * Sorting * Property details * Gallery * Video * Map
* Enquiry * Site visit * Login * Registration * Wishlist * Comparison * Notifications * Mobile responsiveness
ADMIN TESTING:
* Login * Logout * Dashboard * Create property * Edit property * Publish property * Unpublish property * Archive property
* Delete property * Change price * Change status * Upload image * Delete image * Reorder images * Upload video
* Delete video * Upload documents * Manage enquiries * Manage site visits * Manage bookings * Manage website content
NEGATIVE TESTING:
* Invalid input * Missing required fields * Unauthorized API calls * Invalid file types * Oversized files * Duplicate records
* Invalid property IDs * Deleted property access * Sold property booking * Reserved property booking
* Unauthorized admin access * Expired sessions * Invalid authentication tokens
EDGE CASES:
* Property has no images * Property has one image * Property has many images * Property has no video
* Property has no map coordinates * Property has no nearby places * Property price changed
* Property becomes sold while customer is viewing it * Property becomes reserved during booking
* Customer submits multiple enquiries * Customer cancels site visit
* Admin deletes/archives a property with existing enquiries * Network failure during upload
* Network failure during enquiry submission

Recommended production architecture:
Frontend: Next.js / React; Backend: FastAPI; Database: PostgreSQL;
Storage: Object storage for images/videos/documents; Maps: Google Maps or Mapbox;
Authentication: Secure session/JWT-based authentication
Deployment: Frontend → Backend/API → PostgreSQL → Object Storage
Use separate environments: * Development * Staging * Production
Use environment variables for: * Database credentials * API keys * Storage credentials * Authentication secrets * Payment credentials
Never hardcode secrets.
Implement: * Automated PostgreSQL backups * Storage backups * Backup retention policy * Database recovery procedure * Disaster recovery documentation
Important property information must not depend on a single machine/server.

Before launch:
* Complete functional testing * Security testing * Performance testing * Mobile testing * Browser testing * SEO verification
* Analytics verification * Backup verification * Admin access verification * Domain configuration * SSL verification
* Production environment verification
Then launch the customer website.
After launch, monitor:
* Customer behavior * Most viewed properties * Most searched locations * Enquiry conversion * Site visit conversion
* Booking conversion * Sales conversion * Performance * Errors * User feedback
Use real customer behavior to decide what features should be added next.

Do NOT implement every phase at once. The first production-capable MVP should contain:
1. Admin authentication 2. Admin dashboard 3. Property CRUD 4. Property image management 5. Property status management
6. Customer homepage 7. Property listing page 8. Search 9. Basic filtering 10. Property details page 11. Image gallery
12. Map 13. Customer enquiry 14. Admin enquiry management 15. Responsive design 16. Basic security 17. Testing 18. Deployment
The first customer journey should work completely:
Admin adds property → Admin publishes property → Customer discovers property → Customer views property
→ Customer submits enquiry → Admin receives enquiry → Admin contacts customer
Once this flow is stable, implement:
Site Visits → Customer Accounts → Wishlist → Comparison → Booking → Payments → CMS → Notifications → Analytics → Advanced features

1. This is NOT an OLX clone.
2. There are NO third-party sellers.
3. Customers cannot list or sell their own properties.
4. Only authorized admins can create property listings.
5. Admin has complete control over property listings and website assets.
6. Customers are buyers/prospective buyers only.
7. Property information should be structured, detailed, and trustworthy.
8. The website should feel premium and professional.
9. Do not expose private admin functionality to customers.
10. Do not implement unnecessary features before the core property discovery and enquiry flow works.
11. Build the system modularly so future features can be added without rewriting the entire application.
12. Prioritize security, data integrity, performance, mobile responsiveness, and maintainability.

The final platform should function as:
A premium, company-owned digital land-selling platform where our company controls the entire property inventory and customer journey.
ADMIN: Manage properties, Manage assets, Manage content, Manage enquiries, Manage site visits, Manage bookings,
Manage customers, Manage website, View analytics, Control property availability
CUSTOMER: Discover properties, Search, Filter, View detailed land information, View photos/videos, View map,
Save properties, Compare properties, Submit enquiries, Schedule site visits, Book properties,
Eventually complete the purchase process
The platform should provide a trustworthy and premium experience from discovering a property all the way through
enquiry, site visit, booking, and eventual purchase.
```
