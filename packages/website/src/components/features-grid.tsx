import { FadeIn } from "@/components/ui/fade-in";
import { FEATURES } from "@/data/features";

export function FeaturesGrid() {
  return (
    <section id="features" className="py-24 px-6">
      <div className="max-w-5xl mx-auto">
        <FadeIn>
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-bold tracking-tight mb-4">
              Built for real environments.
            </h2>
            <p className="text-text-muted max-w-lg mx-auto leading-relaxed">
              Mixed installs happen. PATH drift happens. kitup updates the tool
              you are actually invoking.
            </p>
          </div>
        </FadeIn>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {FEATURES.map((feature, index) => (
            <FadeIn key={feature.id}>
              <div
                className={`bg-bg-raised border border-border rounded-lg p-6 h-full hover:border-border-hover transition-colors duration-200 ${
                  feature.span === "half" ? "md:col-span-2" : ""
                }`}
              >
                <span className="text-xs font-mono text-text-dim tracking-wider">
                  {feature.number}
                </span>
                <h3 className="text-lg font-semibold mt-3 mb-2">
                  {feature.title}
                </h3>
                <p className="text-sm text-text-muted leading-relaxed">
                  {feature.description}
                </p>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}
