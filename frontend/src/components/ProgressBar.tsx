import { clsx } from "clsx";

export function ProgressBar({
  value,
  status,
}: {
  value: number;
  status?: string;
}) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div className="w-full">
      <div className="flex items-center justify-between text-xs text-slate-400 mb-1">
        <span>{status ?? ""}</span>
        <span>{pct.toFixed(1)}%</span>
      </div>
      <div className="h-2 w-full bg-slate-800 rounded-full overflow-hidden">
        <div
          className={clsx("h-full transition-all duration-300", {
            "bg-emerald-500": status === "completed",
            "bg-amber-500":
              status === "completed_with_errors" ||
              status === "partially_failed",
            "bg-rose-500": status === "failed",
            "bg-sky-500": ![
              "completed",
              "completed_with_errors",
              "partially_failed",
              "failed",
            ].includes(status ?? ""),
          })}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}
