/** Mobile-only pill drag handle shown at the top of slide-up panels. */
export default function DragHandle() {
  return (
    <div className="md:hidden flex justify-center pt-2.5 pb-1 shrink-0">
      <div className="w-8 h-1 rounded-full bg-on-surface-variant/30" />
    </div>
  );
}
