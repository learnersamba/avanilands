import { HomeView } from "@/components/views/home-view";
import {
  getBanners,
  getFaqs,
  getFeaturedProperties,
  getLocations,
  getPropertyTypes,
  getRecentProperties,
  getSiteContent,
  getTestimonials,
} from "@/lib/data";

export default async function HomePage() {
  const [content, faqs, testimonials, banners, featured, recent, locations, types] = await Promise.all([
    getSiteContent(),
    getFaqs(),
    getTestimonials(),
    getBanners(),
    getFeaturedProperties(6),
    getRecentProperties(6),
    getLocations(),
    getPropertyTypes(),
  ]);
  return (
    <HomeView
      content={content}
      faqs={faqs}
      testimonials={testimonials}
      banners={banners}
      featured={featured}
      recent={recent}
      locations={locations}
      types={types}
    />
  );
}
