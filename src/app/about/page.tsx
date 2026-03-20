import type { Metadata } from "next";
import AboutAccordion from "@/components/AboutAccordion";
import WarningAmberOutlinedIcon from "@mui/icons-material/WarningAmberOutlined";
import LightbulbOutlinedIcon from "@mui/icons-material/LightbulbOutlined";
import DirectionsBoatOutlinedIcon from "@mui/icons-material/DirectionsBoatOutlined";
import SecurityOutlinedIcon from "@mui/icons-material/SecurityOutlined";
import MapOutlinedIcon from "@mui/icons-material/MapOutlined";

export const metadata: Metadata = {
  title: "About",
  description:
    "Learn about Lagos ferries, the mapping process, safety information, and data limitations of the Lagos Ferry Map.",
  openGraph: {
    title: "About Lagos Ferry Map",
    description:
      "Learn about Lagos ferries, the mapping process, safety information, and data limitations.",
  },
  alternates: { canonical: "/about" },
};

import { REPORT_FORM_URL } from "@/lib/constants";

const linkClass =
  "text-primary underline underline-offset-2 hover:text-primary-dark";

const accordionItems = [
  {
    title: "Limitations",
    icon: <WarningAmberOutlinedIcon />,
    content: (
      <>
        <p>
          Private, informal transit operations are always subject to change. This information was collected in February 2026 and updates will be published on a quarterly basis. The scope of the map is primarily focused on the Lagos metropolitan area, rather than the entire state, because we are focused on reducing road congestion in the city of Lagos. However, we are gradually expanding the map for coverage of all the full state.
        </p>
        <p>
          If you see anything that&apos;s missing or incorrect, please{" "}
          <a href={REPORT_FORM_URL} className={linkClass} target="_blank" rel="noopener noreferrer">
            let us know
          </a>
          .
        </p>
      </>
    ),
  },
  {
    title: "Context and Motivation",
    icon: <LightbulbOutlinedIcon />,
    content: (
      <>
        <p>
          This is the first-ever comprehensive map of private and public ferries
          in Lagos.
        </p>
        <p>
          In Lagos, a city ranked among the worst in the world for road congestion,
          ferries are an underutilised and poorly understood transportation
          alternative. Part of the problem is the lack of information; private, informal
          ferries have no public documentation, and people only learn about them
          through word-of-mouth.
        </p>
        <p>
          That&apos;s why we deployed a team of data collectors to gather
          detailed information about the routes, schedules, and fares. The goal is to educate Lagos commuters about the availability and
          advantages of water transit alternatives, enabling people to have
          faster, more enjoyable commutes.
        </p>
        <p>
          Originally incubated at {" "}
          <a href="https://stears.co" className={linkClass} target="_blank" rel="noopener noreferrer">
            Stears Open Data
          </a>
          , we published this project as free
          open data because we believe in the importance of ferry transportation
          and want to spark dialog about reducing road congestion by expanding
          robust multi-modal transportation in Lagos.
        </p>
      </>
    ),
  },
  {
    title: "About the Ferries",
    icon: <DirectionsBoatOutlinedIcon />,
    content: (
      <>
        <h3 className="text-on-surface font-bold">
          Ferry operators
        </h3>
        <p>
          The Lagos State government runs a ferry service called{" "}
          <strong className="text-on-surface font-medium">LagFerry</strong>,
          which has been actively expanding and improving over the decades. The
          majority of routes, however, operate through private, informal
          operators. Until this project from Stears Open Data, there has been no
          online documentation of all the private routes, schedules, and fares.
        </p>
        <h3 className="text-on-surface font-bold">
          Type of facilities and quality
        </h3>
        <p>
          Lagos offers varied ferry infrastructure: from modern ferry terminals
          with air-conditioned waiting rooms and other amenities, to undeveloped
          landings where boats pull up on sand banks on the shoreline. Some locations are quite informal and undeveloped, making them a better fit for commuters who are more adventurous and don&apos;t mind getting their shoes muddy.
        </p>
        <p>
          Our interactive map presents the full spectrum of ferry facilities and routes. The ferry facilities are color-coded based on their level of development. Pictures and links to the Google Maps pages are also provided to help you imagine what it&apos;s like at each site.
        </p>
        <h3 className="text-on-surface font-bold">
          Types of boats
        </h3>
        <p>
          Within the Lagos ferry network, there is a wide range of boats, varying in passenger capacity, speed, and covered protection from rain and wind. The largest and most stable are the catamarans run by LagFerry on the busier routes. The smallest and most exposed are banana boats.
        </p>
        <p>Our map indicates which types of boats operate on each ferry route, so you know what to expect.</p>
        <h3 className="text-on-surface font-bold">
          Schedules
        </h3>
        <p>
          Most ferry routes have very fluid, flexible schedules, with boats departing only once they are full of passengers. Even the government-run LagFerry routes don&apos;t always have a strict departure time; they often wait until the boats are full.
        </p>
        <p>
          Our map clarifies these schedules and how often the boats typically depart. In addition to fixed routes, where passengers pay for individual tickets, our map includes charter options, where passengers pay to charter the entire boat to reach any desired destination. There often isn&apos;t a strict line between the two, with private/informal operators switching to offering charter services when there is low passenger demand for fixed routes, especially on weekends or during the lull between peak weekday commuting periods.
        </p>
      </>
    ),
  },
  {
    title: "Government Oversight and Safety",
    icon: <SecurityOutlinedIcon />,
    content: (
      <>
        <p>
          In Lagos, passenger ferry transportation is overseen by both national
          and state agencies to ensure safety and regulatory compliance.
        </p>
        <p>
          At the national level, the <strong className="text-on-surface font-bold">
            NIWA — National Inland Waterways Authority
          </strong>{" "}
          is responsible for regulating inland waterways, including those in Lagos. NIWA&apos;s duties encompass setting safety standards for vessels, approving and monitoring ferry operations, and sanctioning illegal activities on the waterways. They collaborate with other bodies to maintain navigable channels and ensure the safety of boat operators and passengers.
        </p>
        <p>
          At the state level, the <strong className="text-on-surface font-bold">
            LASWA — Lagos State Waterways Authority
          </strong>{" "}
          is pivotal in managing and regulating water transportation. Established to provide alternatives to road traffic congestion, LASWA oversees the operations of boats and ferries, ensuring they adhere to safety protocols. All passenger vehicles must be registered with LASWA and are required to provide lifejackets for passengers. The agency conducts operator training programs and educates the public on water safety. Additionally, LASWA has deployed water guards across various terminals to monitor compliance and enhance passenger safety.
        </p>
        <p>
          The <strong className="text-on-surface font-bold">Lagos State Ferry Services (LagFerry)</strong>{" "}
          prioritises its passengers&apos; safety through strict operating procedures. All passengers and crew are mandated to wear life jackets during voyages, and the agency ensures regular maintenance of its boats to uphold operational safety standards. To enhance emergency preparedness, LagFerry personnel undergo training in survival techniques and search and rescue operations. Additionally, LagFerry has implemented a digital surveillance system, featuring real-time vessel monitoring, CCTV cameras, and geo-fencing capabilities, to bolster passengers&apos; and crew&apos;s safety and security.
        </p>
      </>
    ),
  },
  {
    title: "Data and Mapping Process",
    icon: <MapOutlinedIcon />,
    content: (
      <>
        <p>
          This is the first-ever comprehensive map of private and public ferries
          in Lagos. It was produced through a combination of data extraction from
          online sources and field data collection.
        </p>
        <p>
          The scope focuses on the Lagos metropolitan area, rather than the
          entire state, because we are focused on reducing road congestion in the
          city of Lagos.
        </p>
        <p>The methodology involved:</p>
        <ul className="space-y-2">
          {[
            "Building from a list of terminals, jetties, and landings from LASWA",
            "Mining Google Maps and OpenStreetMap for ferry-related locations",
            "Hiring field contractors to visit sites and verify ferry activity",
            "Interviewing operators about routes, stops, schedules, and fares",
            "Recording GPS logs of ferry paths and stops",
            "Compiling data into an interactive map",
          ].map((item) => (
            <li key={item} className="flex items-start gap-3">
              <span className="mt-2 w-1.5 h-1.5 rounded-full bg-primary shrink-0" />
              {item}
            </li>
          ))}
        </ul>
        <p>
          This information was collected in{" "}
          <strong className="text-on-surface font-medium">February 2026</strong> and is updated quarterly.
          If you see anything that&apos;s missing or incorrect, please{" "}
          <a href={REPORT_FORM_URL} className={linkClass} target="_blank" rel="noopener noreferrer">
            let us know
          </a>
          .
        </p>
      </>
    ),
  },
];

export default function AboutPage() {
  return (
    <section className="max-w-4xl mx-auto px-4 py-16">
      <h1 className="text-[32px] font-normal leading-10 text-on-surface mb-3">
        About the Lagos Ferry Map
      </h1>
      <p className="text-base leading-6 text-on-surface-variant mb-3">
        <a className="link" href="https://www.publictech.studio/">Public Tech Studio</a> launched this project in 2025 to educate Lagos commuters about the availability and advantages of ferry transportation, aiming to reduce road congestion and promote more robust multi-modal public transit. Through a new partnership, the <a className="link" href="https://lagoswaterways.com/">Lagos State Waterways Authority </a> is also contributing data on ferry operations at the facilities under their oversight.
      </p>
      <p className="text-base leading-6 text-on-surface-variant mb-3">
        Learn about Lagos ferries, the mapping process, safety information, and
        data limitations.
      </p>

      <AboutAccordion items={accordionItems} />
    </section>
  );
}
