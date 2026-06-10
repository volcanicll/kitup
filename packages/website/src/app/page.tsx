import { Navbar } from "@/components/navbar";
import { Hero } from "@/components/hero";
import { TUIShowcase } from "@/components/tui-showcase";
import { FeaturesGrid } from "@/components/features-grid";
import { ToolsList } from "@/components/tools-list";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <main className="min-h-screen">
      <Navbar />
      <Hero />
      <TUIShowcase />
      <FeaturesGrid />
      <ToolsList />
      <Footer />
    </main>
  );
}
