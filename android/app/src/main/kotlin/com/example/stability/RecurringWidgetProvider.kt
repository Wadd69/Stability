package com.example.stability

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Widget d'écran d'accueil affichant les prochaines transactions
// récurrentes ("ce qui reste à passer"). Le texte affiché est
// entièrement préformaté côté Dart (RecurringWidgetService) — ce
// provider ne fait qu'injecter la donnée dans le RemoteViews.
class RecurringWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.recurring_widget).apply {
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.recurring_widget_container, pendingIntent)

            val text = widgetData.getString("recurring_text", null)
            setTextViewText(
                R.id.recurring_widget_text,
                text ?: "Aucune échéance à venir",
            )
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
