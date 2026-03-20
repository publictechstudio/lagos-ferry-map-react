/** Inline loading spinner with a text message. */
export default function LoadingSpinner({ message }: { message: string }) {
  return (
    <div className="flex items-center gap-2 text-on-surface-variant text-sm py-4">
      <div className="w-4 h-4 border-2 border-primary border-t-transparent rounded-full animate-spin shrink-0" />
      {message}
    </div>
  );
}
