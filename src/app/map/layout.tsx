export default function MapLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <style>{`#site-footer { display: none; }`}</style>
      {children}
    </>
  );
}
