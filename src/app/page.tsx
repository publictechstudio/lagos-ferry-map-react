import HeroSection from "@/components/HeroSection";

export default function HomePage() {
  return (
    <>
      <HeroSection />

      <section className="max-w-4xl mx-auto px-4 py-16">
        {/* Headline Medium — 28px / 400 */}
        <h2 className="text-[28px] font-normal leading-9 text-on-surface mb-4">
          The first comprehensive ferry map for Lagos
        </h2>
        {/* Body Large — 16px / 400 */}
        <p className="text-base leading-6 text-on-surface-variant mb-5">
          The Lagos metropolitan area has an extensive network of ferry terminals and water transport
          routes that most residents don&apos;t know about. Lagos Ferry Map brings
          together every terminal, route, schedule, and fare into one free, open
          resource.
        </p>
        <p className="text-base leading-6 text-on-surface-variant mb-5">
          Whether you commute daily or are visiting Lagos for the first time,
          this site gives you the tools to beat the traffic and navigate the city&apos;s waterways with
          confidence.
        </p>
      </section>
      <section>
        <div className="bg-[#1976D2]/10">
          <div className="max-w-4xl mx-auto px-4 py-12">
            <h2 className="text-[28px] font-normal leading-9 text-on-surface mb-4">
              Who&apos;s beind the map?
            </h2>
            <p className="text-base leading-6 text-on-surface-variant mb-5">
              <a className="link" href="https://www.publictech.studio/">Public Tech Studio</a> launched this project in 2025 to educate Lagos commuters about the availability and advantages of ferry transportation, aiming to reduce road congestion and promote more robust multi-modal public transit.</p>
            <p className="text-base leading-6 text-on-surface-variant mb-5">
              Through a new partnership, the <a className="link" href="https://lagoswaterways.com/">Lagos State Waterways Authority </a> is also contributing data on ferry operations at the facilities under their oversight.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
